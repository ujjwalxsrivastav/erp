import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/teacher_service.dart';

class UploadMarksScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String teacherId;
  final String year;
  final String section;

  const UploadMarksScreen({
    super.key,
    required this.subject,
    required this.teacherId,
    required this.year,
    required this.section,
  });

  @override
  State<UploadMarksScreen> createState() => _UploadMarksScreenState();
}

class _UploadMarksScreenState extends State<UploadMarksScreen> {
  final _teacherService = TeacherService();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _selectedExamType = 'Mid Term';
  final Map<String, TextEditingController> _marksControllers = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _teacherService.getStudentsForClass(
        subjectId: widget.subject['subject_id'] ?? widget.subject['course_id'],
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
    for (var controller in _marksControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              subjectId:
                  widget.subject['subject_id'] ?? widget.subject['course_id'],
              teacherId: widget.teacherId,
              examType: _selectedExamType,
              marks: marks,
              totalMarks: 100,
              year: widget.year,
              section: widget.section,
            );
            if (success) {
              successCount++;
              // Clear the controller after successful save
              _marksControllers[student['student_id']]?.clear();
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          GlassCard(
                            child: DropdownButtonFormField<String>(
                              value: _selectedExamType,
                              decoration: const InputDecoration(
                                labelText: 'Select Exam Type',
                                prefixIcon:
                                    Icon(Icons.assignment_turned_in_outlined),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              items: [
                                'Mid Term',
                                'End Semester',
                                'Quiz',
                                'Assignment'
                              ]
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedExamType = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_students.isEmpty)
                            Center(
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
                          else
                            ..._students.map((student) {
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
                                              style:
                                                  AppTheme.bodyLarge.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.dark,
                                              ),
                                            ),
                                            Text(
                                              student['student_id'],
                                              style:
                                                  AppTheme.bodySmall.copyWith(
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
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12),
                                            suffixText: '/100',
                                            suffixStyle: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              child: FloatingActionButton.extended(
                onPressed: _saveMarks,
                backgroundColor: AppTheme.teacherPrimary,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  'Save All Marks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
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
              Positioned(
                top: -30,
                right: -30,
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
                    Text(
                      'Upload Marks',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.subject['subject_name'] ?? widget.subject['course_name']} • Year ${widget.year} ${widget.section}',
                      style: AppTheme.h3.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
