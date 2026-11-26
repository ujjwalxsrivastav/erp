import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/erp_provider.dart';
import 'routes/app_router.dart';
import 'services/supabase_service.dart';
import 'services/offline_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (declared as a Flutter asset in pubspec.yaml).
  // Falls back to --dart-define values if the asset is unavailable.
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env file loaded successfully');
  } catch (e) {
    print('⚠️ Could not load .env asset (using --dart-define fallbacks): $e');
    try {
      dotenv.loadFromString(envString: '', isOptional: true);
    } catch (_) {}
  }

  // Initialize Supabase & Core Services
  try {
    await SupabaseService.initialize();
    print('✅ Supabase initialization complete');

    // Initialize offline service for connectivity monitoring
    OfflineService().initialize();
    print('✅ Offline service initialized');

    // Initialize Dual-Mode ERP provider
    await ERPProvider().loadFromPrefs();
    print('✅ ERP Provider initialized');
  } catch (e) {
    print('⚠️ Error during initialization: $e');
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
