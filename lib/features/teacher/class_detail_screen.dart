import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/teacher_service.dart';

class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String teacherId;
  final String year;
  final String section;

  const ClassDetailScreen({
    super.key,
    required this.subject,
    required this.teacherId,
    required this.year,
    required this.section,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _teacherService = TeacherService();

  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  // Assignment Form
  final _assignmentTitleController = TextEditingController();
  final _assignmentDescController = TextEditingController();
  File? _selectedFile;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  // Marks Form
  String _selectedExamType = 'Mid Term';
  final Map<String, TextEditingController> _marksControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _teacherService.getStudentsForClass(
        subjectId: widget.subject['subject_id'],
        year: widget.year,
        section: widget.section,
      );

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;

          // Initialize controllers for each student
          for (var student in students) {
            _marksControllers[student['student_id']] = TextEditingController();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading students: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assignmentTitleController.dispose();
    _assignmentDescController.dispose();
    for (var controller in _marksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadAssignment() async {
    if (_assignmentTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _teacherService.uploadAssignment(
        title: _assignmentTitleController.text,
        description: _assignmentDescController.text,
        subjectId: widget.subject['subject_id'],
        teacherId: widget.teacherId,
        dueDate: _dueDate,
        year: widget.year,
        section: widget.section,
        file: _selectedFile,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment uploaded successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          _assignmentTitleController.clear();
          _assignmentDescController.clear();
          setState(() => _selectedFile = null);
        } else {
          throw Exception('Upload failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload assignment: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveMarks() async {
    setState(() => _isLoading = true);
    int successCount = 0;
    List<String> errors = [];

    try {
      for (var student in _students) {
        final marksText = _marksControllers[student['student_id']]?.text;
        if (marksText != null && marksText.isNotEmpty) {
          final marks = double.tryParse(marksText);
          if (marks != null) {
            final success = await _teacherService.uploadMarks(
              studentId: student['student_id'],
              subjectId: widget.subject['subject_id'],
              teacherId: widget.teacherId,
              examType: _selectedExamType,
              marks: marks,
              totalMarks: 100, // Default total marks
              year: widget.year,
              section: widget.section,
            );
            if (success) {
              successCount++;
            } else {
              errors.add('Failed for ${student['name']}');
            }
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (errors.isEmpty && successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Marks saved successfully for $successCount students'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Saved $successCount. Errors: ${errors.join(", ")}'),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No marks to save or all failed.'),
              backgroundColor: AppTheme.info,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(),
            ],
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssignmentTab(),
                      _buildMarksTab(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.teacherGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${widget.year} • Section ${widget.section}',
                        style: AppTheme.caption.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.subject['subject_name'],
                      style: AppTheme.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 40), // Space for TabBar
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorPadding: const EdgeInsets.all(4),
            labelColor: AppTheme.teacherPrimary,
            unselectedLabelColor: Colors.white,
            labelStyle:
                AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Assignments'),
              Tab(text: 'Upload Marks'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.teacherPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: AppTheme.teacherPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'New Assignment',
                      style: AppTheme.h4.copyWith(color: AppTheme.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _assignmentTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Assignment Title',
                    hintText: 'e.g., Chapter 1 Review',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _assignmentDescController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter assignment details...',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _dueDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.extraLightGray),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: AppTheme.mediumGray),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Due Date', style: AppTheme.caption),
                                  Text(
                                    _dueDate.toString().split(' ')[0],
                                    style: AppTheme.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.extraLightGray),
                            borderRadius: BorderRadius.circular(12),
                            color: _selectedFile != null
                                ? AppTheme.teacherPrimary.withOpacity(0.05)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedFile != null
                                    ? Icons.check_circle_outline
                                    : Icons.attach_file,
                                color: _selectedFile != null
                                    ? AppTheme.teacherPrimary
                                    : AppTheme.mediumGray,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Attachment', style: AppTheme.caption),
                                    Text(
                                      _selectedFile != null
                                          ? 'File Selected'
                                          : 'Choose File',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _selectedFile != null
                                            ? AppTheme.teacherPrimary
                                            : AppTheme.dark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _uploadAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teacherPrimary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppTheme.teacherPrimary.withOpacity(0.4),
                    ),
                    child: const Text(
                      'Create Assignment',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksTab() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: GlassCard(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedExamType,
                  decoration: const InputDecoration(
                    labelText: 'Select Exam Type',
                    prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: ['Mid Term', 'End Semester', 'Quiz', 'Assignment']
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _selectedExamType = value);
                  },
                ),
              ),
            ),
            Expanded(
              child: _students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: AppTheme.lightGray),
                          const SizedBox(height: 16),
                          Text(
                            'No students found',
                            style: AppTheme.bodyLarge
                                .copyWith(color: AppTheme.mediumGray),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.teacherGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.teacherPrimary
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      student['name'][0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['name'],
                                        style: AppTheme.bodyLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.dark,
                                        ),
                                      ),
                                      Text(
                                        student['student_id'],
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.mediumGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppTheme.extraLightGray),
                                  ),
                                  child: TextField(
                                    controller: _marksControllers[
                                        student['student_id']],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.teacherPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '00',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      suffixText: '/100',
                                      suffixStyle: TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: ElevatedButton(
              onPressed: _saveMarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Save All Marks',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
