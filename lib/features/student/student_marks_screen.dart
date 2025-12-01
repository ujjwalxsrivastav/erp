import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';

class StudentMarksScreen extends StatefulWidget {
  const StudentMarksScreen({super.key});

  @override
  State<StudentMarksScreen> createState() => _StudentMarksScreenState();
}

class _StudentMarksScreenState extends State<StudentMarksScreen> {
  final _authService = AuthService();
  final _studentService = StudentService();

  String _selectedExamType = 'Mid Term';
  List<String> _examTypes = ['Mid Term', 'End Semester', 'Quiz', 'Assignment'];
  List<Map<String, dynamic>> _allMarks = [];
  List<Map<String, dynamic>> _filteredMarks = [];
  bool _isLoading = true;
  Map<String, double> _stats = {
    'total': 0,
    'obtained': 0,
    'percentage': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  Future<void> _loadMarks() async {
    try {
      print('🔍 Starting to load marks...');
      final username = await _authService.getCurrentUsername();
      print('👤 Username: $username');

      if (username != null) {
        print('📊 Fetching marks from service...');
        final marks = await _studentService.getStudentMarks(username);
        print('✅ Received ${marks.length} marks records');

        // Debug: Print all marks
        for (var mark in marks) {
          print(
              '📝 Mark: ${mark['exam_type']} - ${mark['subjects']?['subject_name']} - ${mark['marks_obtained']}/${mark['total_marks']}');
        }

        // Extract unique exam types from actual data if available, otherwise keep defaults
        final dataExamTypes =
            marks.map((m) => m['exam_type'] as String).toSet().toList();

        print('📋 Exam types found: $dataExamTypes');

        if (dataExamTypes.isNotEmpty) {
          // Merge with defaults to ensure standard options exist
          final Set<String> allTypes = {..._examTypes, ...dataExamTypes};
          _examTypes = allTypes.toList();
        }

        if (mounted) {
          setState(() {
            _allMarks = marks;
            _isLoading = false;
            _filterMarks();
          });
        }
      } else {
        print('❌ No username found');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print('❌ Error loading marks: $e');
      print('Stack trace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterMarks() {
    final filtered =
        _allMarks.where((m) => m['exam_type'] == _selectedExamType).toList();

    double totalObtained = 0;
    double totalMax = 0;

    for (var mark in filtered) {
      totalObtained += (mark['marks_obtained'] as num).toDouble();
      totalMax += (mark['total_marks'] as num).toDouble();
    }

    setState(() {
      _filteredMarks = filtered;
      _stats = {
        'total': totalMax,
        'obtained': totalObtained,
        'percentage': totalMax > 0 ? (totalObtained / totalMax) * 100 : 0,
      };
    });
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildExamSelector(),
                      const SizedBox(height: 24),
                      if (!_isLoading) _buildStatsCard(),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredMarks.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64, color: AppTheme.lightGray),
                        const SizedBox(height: 16),
                        Text(
                          'No marks found for $_selectedExamType',
                          style: AppTheme.bodyLarge
                              .copyWith(color: AppTheme.mediumGray),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final mark = _filteredMarks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildMarkCard(mark),
                        );
                      },
                      childCount: _filteredMarks.length,
                    ),
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
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.studentGradient,
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
                      'My Marks',
                      style: AppTheme.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your academic performance',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
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

  Widget _buildExamSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _examTypes.map((type) {
          final isSelected = _selectedExamType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedExamType = type;
                  _filterMarks();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.studentPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.studentPrimary
                        : AppTheme.extraLightGray,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.studentPrimary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.mediumGray,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats['total'] == 0) return const SizedBox.shrink();

    return GlassCard(
      gradient: LinearGradient(
        colors: [
          AppTheme.studentPrimary.withOpacity(0.8),
          AppTheme.studentLight.withOpacity(0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total Marks',
            '${_stats['obtained']?.toStringAsFixed(0)}/${_stats['total']?.toStringAsFixed(0)}',
            Icons.assignment_turned_in,
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildStatItem(
            'Percentage',
            '${_stats['percentage']?.toStringAsFixed(1)}%',
            Icons.pie_chart,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTheme.h3.copyWith(color: Colors.white),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkCard(Map<String, dynamic> mark) {
    final percentage = (mark['marks_obtained'] / mark['total_marks']) * 100;
    Color gradeColor;
    if (percentage >= 90) {
      gradeColor = AppTheme.success;
    } else if (percentage >= 75) {
      gradeColor = AppTheme.studentPrimary;
    } else if (percentage >= 50) {
      gradeColor = AppTheme.warning;
    } else {
      gradeColor = AppTheme.error;
    }

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: gradeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mark['subjects']?['subject_name'] ?? 'Unknown Subject',
                  style: AppTheme.h5.copyWith(color: AppTheme.dark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Max Marks: ${mark['total_marks']}',
                  style:
                      AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mark['marks_obtained'].toString(),
                style: AppTheme.h3.copyWith(color: AppTheme.dark),
              ),
              Text(
                'Obtained',
                style: AppTheme.caption.copyWith(color: AppTheme.mediumGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
