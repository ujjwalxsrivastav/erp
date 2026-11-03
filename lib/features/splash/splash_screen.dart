import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Wait for splash animation
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        final isValid = await _authService.verifySession();

        if (isValid) {
          final role = await _authService.getCurrentUserRole();
          final instituteType = await _authService.getCurrentInstituteType();
          final isSchool = instituteType == 'school';

          if (!mounted) return;

          if (isSchool) {
            switch (role?.toLowerCase()) {
              case 'student':
                context.go('/school/student-dashboard');
                break;
              case 'teacher':
                context.go('/school/teacher-dashboard');
                break;
              case 'admin':
                context.go('/school/admin-dashboard');
                break;
              case 'parent':
                context.go('/school/parent-dashboard');
                break;
              default:
                context.go('/school/admin-dashboard');
            }
          } else {
            switch (role?.toLowerCase()) {
              case 'student':
                context.go('/student-dashboard');
                break;
              case 'teacher':
                context.go('/teacher-dashboard');
                break;
              case 'admin':
                context.go('/admin-dashboard');
                break;
              case 'hr':
                context.go('/hr-dashboard');
                break;
              case 'hod':
                context.go('/hod-dashboard');
                break;
              case 'warden':
                context.go('/warden-dashboard');
                break;
              case 'transport_officer':
              case 'transportofficer':
                context.go('/transport-dashboard');
                break;
              case 'conductor':
                context.go('/conductor-dashboard');
                break;
              case 'accountant':
                context.go('/accountant-dashboard');
                break;
              default:
                context.go('/login');
            }
          }
        } else {
          await _authService.logout();
          if (!mounted) return;
          context.go('/login');
        }
      } else {
        if (!mounted) return;
        context.go('/login');
      }
    } catch (e) {
      print('⚠️ Error during auth check: $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF334155),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Shivalik ERP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'College & School Edition',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
