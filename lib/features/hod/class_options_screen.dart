import 'package:flutter/material.dart';
import 'edit_timetable_screen.dart';

class ClassOptionsScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ClassOptionsScreen({super.key, required this.classData});

  @override
  State<ClassOptionsScreen> createState() => _ClassOptionsScreenState();
}

class _ClassOptionsScreenState extends State<ClassOptionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['class_name'] ?? '';
    final year = widget.classData['year'] ?? 0;
    final section = widget.classData['section'] ?? '';

    // Year-based colors
    List<Color> gradientColors;
    switch (year) {
      case 1:
        gradientColors = [const Color(0xFF10B981), const Color(0xFF059669)];
        break;
      case 2:
        gradientColors = [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
        break;
      case 3:
        gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
        break;
      case 4:
        gradientColors = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
        break;
      default:
        gradientColors = [const Color(0xFF6B7280), const Color(0xFF4B5563)];
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientColors[0],
              gradientColors[1],
              gradientColors[1].withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildAppBar(className, year, section),
              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildOptions(gradientColors),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(String className, int year, String section) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 24),
          // Class Info
          Hero(
            tag: 'class_$className',
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Year $year • Section $section',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Class $className',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Management Portal',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(List<Color> gradientColors) {
    final options = [
      {
        'icon': Icons.calendar_month_rounded,
        'title': 'Timetable',
        'subtitle': 'View & Edit Schedule',
        'color': gradientColors[0],
        'onTap': () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EditTimetableScreen(classData: widget.classData),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          );
        },
      },
      {
        'icon': Icons.campaign_rounded,
        'title': 'Announcements',
        'subtitle': 'Post Class Updates',
        'color': const Color(0xFF8B5CF6),
        'onTap': () {
          _showComingSoon('Announcements');
        },
      },
      {
        'icon': Icons.assessment_rounded,
        'title': 'Class Report',
        'subtitle': 'Performance Analytics',
        'color': const Color(0xFFEC4899),
        'onTap': () {
          _showComingSoon('Class Report');
        },
      },
      {
        'icon': Icons.check_circle_rounded,
        'title': 'Attendance',
        'subtitle': 'View Records',
        'color': const Color(0xFF14B8A6),
        'onTap': () {
          _showComingSoon('Attendance');
        },
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Increased from 0.9
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        return _buildOptionCard(
          options[index],
          index,
        );
      },
    );
  }

  Widget _buildOptionCard(Map<String, dynamic> option, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: option['onTap'] as VoidCallback,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (option['color'] as Color).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative gradient
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          (option['color'] as Color).withOpacity(0.1),
                          (option['color'] as Color).withOpacity(0.0),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(24),
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16), // Reduced from 20
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Added
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(12), // Reduced from 14
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              option['color'] as Color,
                              (option['color'] as Color).withOpacity(0.7),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(14), // Reduced from 16
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (option['color'] as Color).withOpacity(0.3),
                              blurRadius: 10, // Reduced from 12
                              offset: const Offset(0, 4), // Reduced from 6
                            ),
                          ],
                        ),
                        child: Icon(
                          option['icon'] as IconData,
                          color: Colors.white,
                          size: 28, // Reduced from 32
                        ),
                      ),
                      const Spacer(),
                      // Title
                      Text(
                        option['title'] as String,
                        style: const TextStyle(
                          fontSize: 16, // Reduced from 18
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2), // Reduced from 4
                      // Subtitle
                      Text(
                        option['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 12, // Reduced from 13
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow
                Positioned(
                  bottom: 12, // Reduced from 16
                  right: 12, // Reduced from 16
                  child: Container(
                    padding: const EdgeInsets.all(6), // Reduced from 8
                    decoration: BoxDecoration(
                      color: (option['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8), // Reduced from 10
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12, // Reduced from 14
                      color: option['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Colors.white),
            const SizedBox(width: 12),
            Text('$feature - Coming Soon!'),
          ],
        ),
        backgroundColor: const Color(0xFF0891B2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
