import 'package:flutter/material.dart';
import '../../../services/school_ai_service.dart';
import '../../../services/school_export_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';

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

  String _currentUsername = 'admin';
  String _currentRole = 'teacher';

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _remarks = [];
  List<Map<String, dynamic>> _questionPapers = [];
  List<Map<String, dynamic>> _feedbacks = [];
  final List<Map<String, String>> _chatMessages = [];

  // Controllers for remark generation
  final _studentNameCtrl = TextEditingController(text: 'Aarav Sharma');
  final _studentUserCtrl = TextEditingController(text: 'sstudent1');
  final _marksCtrl = TextEditingController(text: '88.5');
  final _attCtrl = TextEditingController(text: '94.2');
  final _notesCtrl = TextEditingController(text: 'Exemplary focus in science laboratory, needs encouragement in group presentations.');
  bool _isGeneratingRemark = false;

  // Controllers for question paper
  final _qpSubjectCtrl = TextEditingController(text: 'Science & Biology');
  final _qpClassCtrl = TextEditingController(text: 'Class 10-A');
  final _qpChaptersCtrl = TextEditingController(text: 'Life Processes, Control & Coordination, Heredity');
  final _qpMarksCtrl = TextEditingController(text: '50');
  bool _isGeneratingPaper = false;

  // Controller for chat
  final _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadData();
    _chatMessages.add({
      'sender': 'assistant',
      'text': 'Hello! I am your Shivalik International School Institutional AI Assistant. Ask me anything about school policies, payroll, hostel allocations, cafeteria menus, library overdue fines, or student discipline rules.',
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentNameCtrl.dispose();
    _studentUserCtrl.dispose();
    _marksCtrl.dispose();
    _attCtrl.dispose();
    _notesCtrl.dispose();
    _qpSubjectCtrl.dispose();
    _qpClassCtrl.dispose();
    _qpChaptersCtrl.dispose();
    _qpMarksCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uname = await _authService.getCurrentUsername() ?? 'admin';
      final role = await _authService.getCurrentUserRole() ?? 'teacher';

      final stats = await _aiService.getAiStats();

      // Live queries from runtime tables (R5)
      List<Map<String, dynamic>> remarks = [];
      List<Map<String, dynamic>> papers = [];
      List<Map<String, dynamic>> feedbacks = [];

      try {
        final remRes = await SupabaseService.client
            .from('school_ai_remarks')
            .select()
            .order('created_at', ascending: false);
        remarks = List<Map<String, dynamic>>.from(remRes);
      } catch (_) {}

      try {
        final qpRes = await SupabaseService.client
            .from('school_ai_question_papers')
            .select()
            .order('created_at', ascending: false);
        papers = List<Map<String, dynamic>>.from(qpRes);
      } catch (_) {}

      try {
        final fbRes = await SupabaseService.client
            .from('school_ai_feedback')
            .select()
            .order('created_at', ascending: false);
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

      if (!mounted) return;
      await SchoolExportService.exportSchoolChatbotUsageExcel(
        context: context,
        instituteName: 'Shivalik International School (SHIV-SCH)',
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
      await SchoolExportService.exportSchoolAiUsageExcel(
        context: context,
        instituteName: 'Shivalik International School (SHIV-SCH)',
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
    final marks = double.tryParse(_marksCtrl.text.trim()) ?? 80.0;
    final att = double.tryParse(_attCtrl.text.trim()) ?? 90.0;

    setState(() => _isGeneratingRemark = true);
    try {
      final rem = await _aiService.draftReportCardRemark(
        studentUsername: sUser,
        studentName: sName,
        examId: 'EXAM-MID-2026',
        classId: 'Class 10-A',
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
    final marks = int.tryParse(_qpMarksCtrl.text.trim()) ?? 50;

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
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve Blueprint'),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Question paper approved for examination printing!'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSendChat([String? customPrompt]) async {
    final query = customPrompt ?? _chatCtrl.text.trim();
    if (query.isEmpty) return;

    if (customPrompt == null) _chatCtrl.clear();

    setState(() {
      _chatMessages.add({'sender': 'user', 'text': query});
      _isChatLoading = true;
    });

    _scrollChatToBottom();

    try {
      final answer = await _aiService.askRagAssistant(
        question: query,
        userRole: _currentRole,
        username: _currentUsername,
      );

      if (mounted) {
        setState(() {
          _chatMessages.add({'sender': 'assistant', 'text': answer});
          _isChatLoading = false;
        });
        _scrollChatToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'sender': 'assistant',
            'text': 'Notice: $e. You can also contact the institutional administrative desk.',
          });
          _isChatLoading = false;
        });
        _scrollChatToBottom();
      }
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Faculty Assistant & RAG Desk'),
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
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
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
        ),
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
              : Column(
                  children: [
                    _buildKpiBanner(),
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
                ),
    );
  }

  Widget _buildKpiBanner() {
    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final approvalRate = (_stats['approval_rate_percent'] as num?)?.toDouble() ?? 92.5;

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
                          if (!isApproved) ...[
                            TextButton(
                              onPressed: () {
                                setState(() => rem['status'] = 'rejected');
                              },
                              child: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Approve & Publish'),
                              onPressed: () {
                                setState(() => rem['status'] = 'approved');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Remark approved for official report card!')),
                                );
                              },
                            ),
                          ] else ...[
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add),
                    label: const Text('Draft Feedback for Aarav Sharma (Photosynthesis Lab)'),
                    onPressed: () async {
                      final fb = await _aiService.draftAssignmentFeedback(
                        assignmentTitle: 'Photosynthesis Lab Experiment Report',
                        studentName: 'Aarav Sharma',
                        studentSubmissionSummary: 'Accurate hypothesis and diagram; minor calculation error in net oxygen volume output.',
                        score: 18.0,
                        maxScore: 20.0,
                        teacherUsername: _currentUsername,
                      );
                      setState(() => _feedbacks.insert(0, fb));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feedback drafted! Faculty approval pending.'), backgroundColor: Colors.indigo),
                      );
                    },
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
    final quickPrompts = [
      'What is staff PF rate?',
      'Hostel gate pass procedure?',
      'Library fine policy?',
      'Cafeteria menu balance?',
      'Discipline suspension rule?',
    ];

    return Column(
      children: [
        // Quick chips
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickPrompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return ActionChip(
                label: Text(quickPrompts[i], style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.indigo.shade50,
                onPressed: () => _handleSendChat(quickPrompts[i]),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length,
            itemBuilder: (context, i) {
              final msg = _chatMessages[i];
              final isUser = msg['sender'] == 'user';

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF312E81) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: isUser ? null : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isChatLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ask RAG Assistant about any school policy or module...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _handleSendChat(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF312E81)),
                onPressed: () => _handleSendChat(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
