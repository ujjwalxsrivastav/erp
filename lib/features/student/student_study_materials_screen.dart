import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/student_service.dart';

class StudentStudyMaterialsScreen extends StatefulWidget {
  final String studentId;

  const StudentStudyMaterialsScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<StudentStudyMaterialsScreen> createState() =>
      _StudentStudyMaterialsScreenState();
}

class _StudentStudyMaterialsScreenState
    extends State<StudentStudyMaterialsScreen> {
  final _studentService = StudentService();
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  String _filterSubject = 'All';
  String _filterType = 'All';
  List<String> _subjects = ['All'];
  final List<String> _materialTypes = [
    'All',
    'Notes',
    'Slides',
    'Reference',
    'Book',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);

    try {
      final materials =
          await _studentService.getStudyMaterials(widget.studentId);

      // Extract unique subjects
      final subjectSet = <String>{'All'};
      for (var material in materials) {
        if (material['subjects'] != null) {
          subjectSet.add(material['subjects']['subject_name']);
        }
      }

      if (mounted) {
        setState(() {
          _materials = materials;
          _subjects = subjectSet.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading study materials: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMaterials {
    return _materials.where((material) {
      final subjectMatch = _filterSubject == 'All' ||
          (material['subjects'] != null &&
              material['subjects']['subject_name'] == _filterSubject);

      final typeMatch =
          _filterType == 'All' || material['material_type'] == _filterType;

      return subjectMatch && typeMatch;
    }).toList();
  }

  Future<void> _downloadFile(String? fileUrl, String title) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file attached'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening: $title'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  IconData _getMaterialIcon(String? type) {
    switch (type) {
      case 'Notes':
        return Icons.note_outlined;
      case 'Slides':
        return Icons.slideshow_outlined;
      case 'Reference':
        return Icons.menu_book_outlined;
      case 'Book':
        return Icons.book_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _getMaterialColor(String? type) {
    switch (type) {
      case 'Notes':
        return const Color(0xFF667EEA);
      case 'Slides':
        return const Color(0xFFF093FB);
      case 'Reference':
        return const Color(0xFF4FACFE);
      case 'Book':
        return const Color(0xFF43E97B);
      default:
        return AppTheme.studentPrimary;
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
          child: Column(
            children: [
              _buildAppBar(),
              _buildFilterChips(),
              _buildTypeFilter(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMaterials.isEmpty
                        ? _buildEmptyState()
                        : _buildMaterialsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Study Materials',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredMaterials.length} materials available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMaterials,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          final isSelected = subject == _filterSubject;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(subject),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterSubject = subject);
              },
              backgroundColor: Colors.white,
              selectedColor: AppTheme.studentPrimary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.dark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              elevation: isSelected ? 4 : 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _materialTypes.length,
        itemBuilder: (context, index) {
          final type = _materialTypes[index];
          final isSelected = type == _filterType;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterType = type);
              },
              backgroundColor: AppTheme.background,
              selectedColor: _getMaterialColor(type),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.dark,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 80,
            color: AppTheme.lightGray,
          ),
          const SizedBox(height: 16),
          Text(
            'No study materials found',
            style: AppTheme.h3.copyWith(color: AppTheme.mediumGray),
          ),
          const SizedBox(height: 8),
          Text(
            _filterSubject == 'All' && _filterType == 'All'
                ? 'No materials uploaded yet'
                : 'Try different filters',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList() {
    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _filteredMaterials.length,
        itemBuilder: (context, index) {
          final material = _filteredMaterials[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildMaterialCard(material),
          );
        },
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final materialType = material['material_type'] ?? 'Other';
    final subjectName = material['subjects']?['subject_name'] ?? 'Unknown';
    final teacherName = material['teacher_details']?['name'] ?? 'Unknown';
    final createdAt = material['created_at'] != null
        ? DateTime.parse(material['created_at'])
        : null;
    final color = _getMaterialColor(materialType);
    final icon = _getMaterialIcon(materialType);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type and subject
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        materialType,
                        style: AppTheme.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subjectName,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            material['title'] ?? 'Untitled Material',
            style: AppTheme.h4.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: 8),

          // Description
          if (material['description'] != null &&
              material['description'].toString().isNotEmpty) ...[
            Text(
              material['description'],
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Teacher and date info
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                teacherName,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                createdAt != null
                    ? DateFormat('MMM dd, yyyy').format(createdAt)
                    : 'Unknown date',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
            ],
          ),

          // Download button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadFile(
                material['file_url'],
                material['title'] ?? 'Study Material',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
              ),
              icon: const Icon(Icons.download, size: 20),
              label: const Text(
                'Download Material',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
