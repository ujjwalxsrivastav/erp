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
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is already logged in
    final isLoggedIn = await _authService.isLoggedIn();

    if (isLoggedIn) {
      // Verify session is still valid
      final isValid = await _authService.verifySession();

      if (isValid) {
        // Get user role and navigate to appropriate dashboard
        final role = await _authService.getCurrentUserRole();

        if (!mounted) return;

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
          default:
            context.go('/login');
        }
      } else {
        // Session invalid, logout and go to login
        await _authService.logout();
        if (!mounted) return;
        context.go('/login');
      }
    } else {
      // Not logged in, go to login screen
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3A8A),
              const Color(0xFF3B82F6),
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
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.school,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Shivalik College ERP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
