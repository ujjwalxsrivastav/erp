import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'services/supabase_service.dart';
import 'services/offline_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Try to load .env file (for mobile), but don't fail if it doesn't exist (web)
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env file loaded successfully');
  } catch (e) {
    print('ℹ️ .env file not found (expected for web builds): $e');
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    print('✅ Supabase initialization complete');

    // Initialize offline service for connectivity monitoring
    OfflineService().initialize();
    print('✅ Offline service initialized');
  } catch (e) {
    print('⚠️ Error during initialization: $e');
    // Continue anyway - app should still run
  }

  // Run the app
  runApp(const MyERPApp());
}

class MyERPApp extends StatelessWidget {
  const MyERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Shivalik ERP',
      theme: AppTheme.lightTheme,
    );
  }
}
