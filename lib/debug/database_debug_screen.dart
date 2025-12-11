import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/teacher_service.dart';

class DatabaseDebugScreen extends StatefulWidget {
  const DatabaseDebugScreen({super.key});

  @override
  State<DatabaseDebugScreen> createState() => _DatabaseDebugScreenState();
}

class _DatabaseDebugScreenState extends State<DatabaseDebugScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  List<String> _logs = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    print(message);
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _logs = [];
    });

    _addLog('🔍 Starting database diagnostics...');
    _addLog('');

    // 1. Check Users table
    await _checkTable('users', 'id, email, role');

    // 2. Check teacher_details table
    await _checkTable(
        'teacher_details', 'teacher_id, name, employee_id, department');

    // 3. Check student_details table
    await _checkTable('student_details', 'student_id, name, year, section');

    // 4. Check subjects table
    await _checkTable('subjects', 'id, subject_name, teacher_id');

    // 5. Check if RLS is blocking
    await _checkRLS();

    _addLog('');
    _addLog('✅ Diagnostics complete!');

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkTable(String tableName, String columns) async {
    try {
      _addLog('📋 Checking table: $tableName');

      final response = await _supabase.from(tableName).select(columns).limit(5);

      _addLog('   ✅ Records found: ${response.length}');

      if (response.isNotEmpty) {
        for (var record in response) {
          _addLog(
              '   📝 ${record.toString().substring(0, record.toString().length > 80 ? 80 : record.toString().length)}...');
        }
      } else {
        _addLog('   ⚠️ Table is empty or RLS is blocking access');
      }
    } catch (e) {
      _addLog('   ❌ Error: $e');
    }
    _addLog('');
  }

  Future<void> _checkRLS() async {
    _addLog('🔐 Checking Auth State...');

    // Check Supabase auth
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _addLog('   👤 Supabase User: ${user.email}');
    } else {
      _addLog('   ⚠️ Supabase Auth: No user (using SharedPreferences auth)');
    }

    // Check SharedPreferences auth
    _addLog('');
    _addLog('🔑 Checking SharedPreferences Auth...');
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    final username = await authService.getCurrentUsername();
    final role = await authService.getCurrentUserRole();

    _addLog('   📍 isLoggedIn: $isLoggedIn');
    _addLog('   👤 Username: ${username ?? "NULL"}');
    _addLog('   🎭 Role: ${role ?? "NULL"}');

    // Test teacher fetch directly
    if (username != null) {
      _addLog('');
      _addLog('🧪 Testing teacher fetch for: $username');
      final teacherService = TeacherService();
      final teacherData = await teacherService.getTeacherDetails(username);

      if (teacherData != null) {
        _addLog('   ✅ Teacher found: ${teacherData['name']}');
        _addLog(
            '   📝 Data: ${teacherData.toString().substring(0, teacherData.toString().length > 100 ? 100 : teacherData.toString().length)}...');
      } else {
        _addLog('   ❌ Teacher NOT found for username: $username');

        // Check what teacher_ids exist
        final allTeachers = await _supabase
            .from('teacher_details')
            .select('teacher_id, name')
            .limit(10);
        _addLog('   📋 Available teacher_ids:');
        for (var t in allTeachers) {
          _addLog('      - ${t['teacher_id']} → ${t['name']}');
        }
      }
    } else {
      _addLog('   ⚠️ Cannot test teacher fetch - no username in session');
    }
  }

  Future<void> _exportAllTables() async {
    setState(() {
      _isLoading = true;
      _logs = [];
    });

    _addLog('📦 EXPORTING ALL TABLES...');
    _addLog('=' * 50);
    _addLog('');

    // Complete list of all tables in the ERP system (from SQL files)
    final tables = [
      // Core tables
      'users',
      'teacher_details',
      'student_details',
      'subjects',
      'student_subjects',
      'classes',

      // Timetable
      'timetable',
      'class_timetable',

      // Assignments & Materials
      'assignments',
      'assignment_submissions',
      'study_materials',
      'announcements',
      'department_announcements',
      'hod_assignments',

      // Leave & HR
      'teacher_leaves',
      'teacher_leave_balance',
      'holidays',
      'teacher_salary',
      'teacher_activity_logs',

      // Events
      'events',

      // Marks - Year 1
      'marks',
      'marks_year1_sectiona_midterm',
      'marks_year1_sectiona_endsem',
      'marks_year1_sectiona_quiz',
      'marks_year1_sectiona_assignment',
      'marks_year1_sectionb_midterm',
      'marks_year1_sectionb_endsem',
      'marks_year1_sectionb_quiz',
      'marks_year1_sectionb_assignment',

      // Marks - Year 2
      'marks_year2_sectiona_midterm',
      'marks_year2_sectiona_endsem',
      'marks_year2_sectiona_quiz',
      'marks_year2_sectiona_assignment',
      'marks_year2_sectionb_midterm',
      'marks_year2_sectionb_endsem',
      'marks_year2_sectionb_quiz',
      'marks_year2_sectionb_assignment',

      // Marks - Year 3
      'marks_year3_sectiona_midterm',
      'marks_year3_sectiona_endsem',
      'marks_year3_sectiona_quiz',
      'marks_year3_sectiona_assignment',
      'marks_year3_sectionb_midterm',
      'marks_year3_sectionb_endsem',
      'marks_year3_sectionb_quiz',
      'marks_year3_sectionb_assignment',

      // Marks - Year 4
      'marks_year4_sectiona_midterm',
      'marks_year4_sectiona_endsem',
      'marks_year4_sectiona_quiz',
      'marks_year4_sectiona_assignment',
      'marks_year4_sectionb_midterm',
      'marks_year4_sectionb_endsem',
      'marks_year4_sectionb_quiz',
      'marks_year4_sectionb_assignment',
    ];

    for (final tableName in tables) {
      await _exportTable(tableName);
    }

    _addLog('');
    _addLog('=' * 50);
    _addLog('✅ EXPORT COMPLETE!');
    _addLog('📋 Check terminal/console for full output');

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _exportTable(String tableName) async {
    try {
      _addLog('📋 TABLE: $tableName');

      final response = await _supabase.from(tableName).select().limit(100);

      if (response.isEmpty) {
        _addLog('   ⚠️ Empty table');
        print('\n-- TABLE: $tableName (EMPTY)');
      } else {
        _addLog('   ✅ ${response.length} rows found');

        // Print to console in detail
        print('\n' + '=' * 60);
        print('TABLE: $tableName');
        print('ROWS: ${response.length}');
        print('=' * 60);

        // Print columns
        if (response.isNotEmpty) {
          print('COLUMNS: ${response.first.keys.join(', ')}');
          print('-' * 60);
        }

        // Print each row
        for (int i = 0; i < response.length; i++) {
          print('ROW ${i + 1}: ${response[i]}');
        }
      }
    } catch (e) {
      _addLog(
          '   ❌ Error: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}');
      print('\n-- TABLE: $tableName (ERROR: $e)');
    }
    _addLog('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Debug'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runDiagnostics,
                    icon: const Icon(Icons.search),
                    label: const Text('Diagnostics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportAllTables,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Tables'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(
              color: Colors.deepPurple,
            ),

          // Logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color color = Colors.white;

                  if (log.contains('✅')) color = Colors.green;
                  if (log.contains('❌')) color = Colors.red;
                  if (log.contains('⚠️')) color = Colors.orange;
                  if (log.contains('🔍') || log.contains('📋'))
                    color = Colors.blue;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
