import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/erp_config.dart';

class ERPProvider extends ChangeNotifier {
  static final ERPProvider _instance = ERPProvider._internal();
  factory ERPProvider() => _instance;
  ERPProvider._internal();

  ERPConfig? _config;
  bool _isLoading = true;

  ERPConfig? get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _config != null;
  ERPMode get mode => _config?.mode ?? ERPMode.college;
  ERPRole get role => _config?.role ?? ERPRole.student;
  bool get isSchool => mode == ERPMode.school;

  static const _keyInstituteType = 'institute_type';
  static const _keyRole = 'user_role';
  static const _keyUsername = 'username';
  static const _keyIsLoggedIn = 'is_logged_in';

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      if (!isLoggedIn) {
        _config = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
      final username = prefs.getString(_keyUsername) ?? '';
      final roleStr = prefs.getString(_keyRole) ?? 'student';
      final instituteType = prefs.getString(_keyInstituteType) ?? 'college';

      _config = ERPConfig(
        mode: ERPConfig.modeFromString(instituteType),
        role: ERPConfig.roleFromString(roleStr),
        username: username,
      );
    } catch (e) {
      _config = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setSession({
    required String username,
    required String role,
    required String instituteType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyInstituteType, instituteType);

    _config = ERPConfig(
      mode: ERPConfig.modeFromString(instituteType),
      role: ERPConfig.roleFromString(role),
      username: username,
    );
    notifyListeners();
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _config = null;
    notifyListeners();
  }
}
