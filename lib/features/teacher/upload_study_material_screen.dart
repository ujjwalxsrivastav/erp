import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/teacher_service.dart';

class UploadStudyMaterialScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String teacherId;
  final String year;
  final String section;

  const UploadStudyMaterialScreen({
    super.key,
    required this.subject,
    required this.teacherId,
    required this.year,
    required this.section,
  });

  @override
  State<UploadStudyMaterialScreen> createState() =>
      _UploadStudyMaterialScreenState();
}

class _UploadStudyMaterialScreenState extends State<UploadStudyMaterialScreen> {
  final _teacherService = TeacherService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  File? _selectedFile;
  String _materialType = 'Notes';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'jpg',
          'png',
          'jpeg'
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadMaterial() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _teacherService.uploadStudyMaterial(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        materialType: _materialType,
        subjectId: widget.subject['subject_id'] ?? widget.subject['course_id'],
        teacherId: widget.teacherId,
        year: widget.year,
        section: widget.section,
        file: _selectedFile!,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Study material uploaded successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          _titleController.clear();
          _descController.clear();
          setState(() {
            _selectedFile = null;
            _materialType = 'Notes';
          });
        } else {
          throw Exception('Upload failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload material: $e'),
            backgroundColor: AppTheme.error,
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
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.teacherPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.library_books_outlined,
                                  color: AppTheme.teacherPrimary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'New Study Material',
                                style:
                                    AppTheme.h4.copyWith(color: AppTheme.dark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Material Title',
                              hintText: 'e.g., Chapter 1 Notes',
                              prefixIcon: Icon(Icons.title_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _materialType,
                            decoration: const InputDecoration(
                              labelText: 'Material Type',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: [
                              'Notes',
                              'Slides',
                              'Reference',
                              'Book',
                              'Other'
                            ]
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _materialType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _descController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description (Optional)',
                              hintText: 'Enter material details...',
                              prefixIcon: Icon(Icons.description_outlined),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _pickFile,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedFile != null
                                      ? AppTheme.teacherPrimary
                                      : AppTheme.extraLightGray,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: _selectedFile != null
                                    ? AppTheme.teacherPrimary.withOpacity(0.05)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedFile != null
                                        ? Icons.check_circle
                                        : Icons.cloud_upload_outlined,
                                    color: _selectedFile != null
                                        ? AppTheme.teacherPrimary
                                        : AppTheme.mediumGray,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFile != null
                                              ? 'File Selected'
                                              : 'Choose File',
                                          style: AppTheme.bodyLarge.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _selectedFile != null
                                                ? AppTheme.teacherPrimary
                                                : AppTheme.dark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedFile != null
                                              ? _selectedFile!.path
                                                  .split('/')
                                                  .last
                                              : 'PDF, DOC, PPT, Images',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.mediumGray,
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
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _uploadMaterial,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.teacherPrimary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor:
                                    AppTheme.teacherPrimary.withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Upload Material',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
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
                      'Upload Study Material',
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
