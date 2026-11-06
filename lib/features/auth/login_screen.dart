// Login Screen with Beautiful UI
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        final role = result['role'] as String;
        final instituteType = result['institute_type'] as String? ?? 'college';
        final isSchool = instituteType == 'school';

        if (role == 'sadmin') {
          context.go('/school/admin-dashboard');
          return;
        }

        if (isSchool) {
          switch (role) {
            case 'student':
              context.go('/school/student-dashboard');
              break;
            case 'teacher':
              context.go('/school/teacher-dashboard');
              break;
            case 'admin':
            case 'sadmin':
              context.go('/school/admin-dashboard');
              break;
            case 'parent':
              context.go('/school/parent-dashboard');
              break;
            default:
              context.go('/school/admin-dashboard');
          }
        } else {
          switch (role) {
            case 'student':
              context.go('/student-dashboard');
              break;
            case 'teacher':
              context.go('/teacher-dashboard');
              break;
            case 'admin':
              context.go('/admin-dashboard');
              break;
            case 'HR':
              context.go('/hr-dashboard');
              break;
            case 'hod':
              context.go('/hod-dashboard');
              break;
            case 'admissiondean':
              context.go('/leads/dean?username=${_usernameController.text.trim()}');
              break;
            case 'counsellor':
              context.go('/leads/counsellor?username=${_usernameController.text.trim()}');
              break;
            case 'temp_student':
              context.go('/temp-student-dashboard?tempId=${_usernameController.text.trim()}');
              break;
            case 'warden':
              context.go('/warden-dashboard');
              break;
            case 'transport_officer':
              context.go('/transport-dashboard');
              break;
            case 'conductor':
              context.go('/conductor-dashboard');
              break;
            case 'accountant':
              context.go('/accountant-dashboard');
              break;
            default:
              context.go('/student-dashboard');
          }
        }
      } else {
        _showError(result['message'] ?? 'Login failed');
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF334155),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppTheme.xxl),
                      _buildLoginForm(),
                      const SizedBox(height: AppTheme.xl),
                      _buildQuickLoginHints(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.studentGradient,
            boxShadow: AppTheme.glowShadow(AppTheme.studentPrimary),
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 50,
            color: AppTheme.white,
          ),
        ),
        const SizedBox(height: AppTheme.lg),
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.studentGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'Shivalik ERP',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Welcome Back!',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.lightGray,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.xl),
      margin: EdgeInsets.zero,
      elevated: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign In',
              style: AppTheme.h3.copyWith(color: AppTheme.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.lg),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: AppTheme.background,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.md),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                filled: true,
                fillColor: AppTheme.background,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.xl),
            GradientButton(
              text: 'Sign In',
              onPressed: _handleLogin,
              gradient: AppTheme.studentGradient,
              icon: Icons.login_rounded,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLoginHints() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.info,
              ),
              const SizedBox(width: AppTheme.sm),
              Text(
                'Quick Login Credentials',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Auto-rate limited to 5 attempts per device',
                child: Text(
                  '🔒 Secure Mode',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          // College credentials
          _buildCredentialRow('College Student', 'BT24CSE154', AppTheme.studentPrimary),
          _buildCredentialRow('College Teacher', 'teacher1', AppTheme.teacherPrimary),
          _buildCredentialRow('Admin', 'admin1', AppTheme.adminPrimary),
          _buildCredentialRow('HR', 'hr1', const Color(0xFF059669)),
          _buildCredentialRow('HOD', 'hod1', const Color(0xFF0891B2)),
          _buildCredentialRow('Warden', 'warden1', const Color(0xFF1E293B)),
          _buildCredentialRow('Transport', 'transportofficer1', const Color(0xFF0C4A6E)),
          _buildCredentialRow('Conductor', 'conductor1', const Color(0xFFD97706)),
          _buildCredentialRow('Accountant', 'accountant1', const Color(0xFF8B5CF6)),
          const SizedBox(height: 6),
          Divider(color: AppTheme.extraLightGray, height: 1),
          const SizedBox(height: 6),
          // School credentials
          _buildCredentialRow('School Student', 'sstudent1', const Color(0xFFFF6B6B)),
          _buildCredentialRow('School Teacher', 'steacher1', const Color(0xFFFF8E53)),
          _buildCredentialRow('School Admin', 'sadmin1', const Color(0xFF9B59B6)),
          _buildCredentialRow('School Admin (Alt)', 'sadmin01', const Color(0xFF8E44AD)),
          _buildCredentialRow('Parent', 'parent1', const Color(0xFF1ABC9C)),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String role, String username, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xs),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.sm),
          Text(
            '$role: ',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            username,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '(same as password)',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.lightGray,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
