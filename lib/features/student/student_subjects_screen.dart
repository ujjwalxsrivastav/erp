import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';

class StudentSubjectsScreen extends StatefulWidget {
  const StudentSubjectsScreen({super.key});

  @override
  State<StudentSubjectsScreen> createState() => _StudentSubjectsScreenState();
}

class _StudentSubjectsScreenState extends State<StudentSubjectsScreen> {
  final _authService = AuthService();
  final _studentService = StudentService();

  List<Map<String, dynamic>> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final username = await _authService.getCurrentUsername();
      if (username != null) {
        // Get timetable entries for this student
        final timetable = await _studentService.getTimetable(username);

        // Extract unique subjects with teacher details
        final Map<String, Map<String, dynamic>> uniqueSubjects = {};

        for (final entry in timetable) {
          final subjectId = entry['subject_id'] as String?;
          if (subjectId != null && !uniqueSubjects.containsKey(subjectId)) {
            uniqueSubjects[subjectId] = {
              'subject_id': subjectId,
              'subjects': entry['subjects'],
              'teacher_details': entry['teacher_details'],
            };
          }
        }

        if (mounted) {
          setState(() {
            _subjects = uniqueSubjects.values.toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading subjects: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTeacherContact(Map<String, dynamic> teacher) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.studentPrimary.withOpacity(0.1),
              child: Text(
                teacher['name']?[0] ?? 'T',
                style: AppTheme.h2.copyWith(color: AppTheme.studentPrimary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              teacher['name'] ?? 'Teacher',
              style: AppTheme.h3.copyWith(color: AppTheme.dark),
            ),
            const SizedBox(height: 24),
            _buildContactItem(
              Icons.email_outlined,
              'Email',
              teacher['email'] ?? 'Not available',
              () async {
                final email = teacher['email'];
                if (email != null) {
                  final uri = Uri.parse('mailto:$email');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              Icons.phone_outlined,
              'Phone',
              teacher['phone'] ?? 'Not available',
              () async {
                final phone = teacher['phone'];
                if (phone != null) {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
      IconData icon, String label, String value, VoidCallback onTap) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.studentPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.studentPrimary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.caption.copyWith(color: AppTheme.mediumGray),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.dark),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 16, color: AppTheme.lightGray),
        ],
      ),
    );
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
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_subjects.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined,
                            size: 64, color: AppTheme.lightGray),
                        const SizedBox(height: 16),
                        Text(
                          'No subjects found',
                          style: AppTheme.bodyLarge
                              .copyWith(color: AppTheme.mediumGray),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final subject = _subjects[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildSubjectCard(subject),
                        );
                      },
                      childCount: _subjects.length,
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
                      'My Subjects',
                      style: AppTheme.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View enrolled courses and faculty',
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

  Widget _buildSubjectCard(Map<String, dynamic> subjectData) {
    final subject = subjectData['subjects'] as Map<String, dynamic>?;
    final teacher = subjectData['teacher_details'] as Map<String, dynamic>?;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.studentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.studentPrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.book, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject?['subject_name'] ?? 'Unknown Subject',
                      style: AppTheme.h5.copyWith(color: AppTheme.dark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.studentLight.withOpacity(0.3),
                  child: Text(
                    teacher?['name']?[0] ?? 'T',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.studentPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faculty',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                      Text(
                        teacher?['name'] ?? 'Not assigned',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.dark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (teacher != null)
                  ElevatedButton.icon(
                    onPressed: () => _showTeacherContact(teacher),
                    icon: const Icon(Icons.contact_phone, size: 16),
                    label: const Text('Contact'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.studentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
