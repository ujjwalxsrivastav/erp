import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class SchoolMastersScreen extends StatefulWidget {
  const SchoolMastersScreen({super.key});

  @override
  State<SchoolMastersScreen> createState() => _SchoolMastersScreenState();
}

class _SchoolMastersScreenState extends State<SchoolMastersScreen>
    with SingleTickerProviderStateMixin {
  final SchoolService _schoolService = SchoolService();
  late TabController _tabController;

  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _teachers = [];

  String _classSearchQuery = '';
  String _selectedClassFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMastersData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMastersData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final classes = await _schoolService.getSchoolClasses();
      final subjects = await _schoolService.getSchoolSubjects();
      final teachers = await _schoolService.getStaffDirectory();

      if (mounted) {
        setState(() {
          _classes = classes;
          _subjects = subjects;
          _teachers = teachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Institutional Master Register',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Academic Classes, Cohorts & Subject Curriculum Catalog',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Master Data',
            onPressed: _loadMastersData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Icons.class_outlined, size: 20),
              text: 'Classes & Sections (${_classes.length})',
            ),
            Tab(
              icon: const Icon(Icons.menu_book_outlined, size: 20),
              text: 'Curriculum Subjects (${_subjects.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorBanner()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildClassesTab(),
                    _buildSubjectsTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'New Class Cohort' : 'New Subject'),
        onPressed: () {
          if (_tabController.index == 0) {
            _showCreateClassDialog();
          } else {
            _showCreateSubjectDialog();
          }
        },
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading master catalog: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMastersData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: CLASSES & SECTIONS
  // ==========================================

  Widget _buildClassesTab() {
    final filtered = _classes.where((c) {
      final name = (c['name']?.toString() ?? '').toLowerCase();
      final sec = (c['section']?.toString() ?? '').toLowerCase();
      final q = _classSearchQuery.toLowerCase();
      return name.contains(q) || sec.contains(q);
    }).toList();

    return Column(
      children: [
        _buildMetricRibbon(
          items: [
            {'label': 'Total Classes', 'val': '${_classes.length}', 'icon': Icons.school, 'color': const Color(0xFF3B82F6)},
            {'label': 'Secondary Blocks', 'val': '${_classes.where((c) => (c['name'] ?? '').contains('10') || (c['name'] ?? '').contains('9')).length}', 'icon': Icons.apartment, 'color': const Color(0xFF10B981)},
            {'label': 'Senior Secondary', 'val': '${_classes.where((c) => (c['name'] ?? '').contains('11') || (c['name'] ?? '').contains('12')).length}', 'icon': Icons.hub, 'color': const Color(0xFF8B5CF6)},
            {'label': 'Active Cohorts', 'val': '${_classes.where((c) => c['is_active'] != false).length}', 'icon': Icons.verified, 'color': const Color(0xFF0EA5E9)},
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search classes and sections (e.g. "Class 10", "A")...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) {
              setState(() => _classSearchQuery = val);
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('No classes found matching search criteria.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final name = item['name']?.toString() ?? 'Class';
                    final section = item['section']?.toString() ?? 'A';
                    final classTeacher = item['class_teacher_id']?.toString() ?? 'Unassigned';
                    final isActive = item['is_active'] != false;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? const Color(0xFFE0F2FE) : Colors.grey.shade200,
                          child: Text(
                            section,
                            style: TextStyle(
                              color: isActive ? const Color(0xFF0284C7) : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              '$name - Section $section',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            if (!isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'INACTIVE',
                                  style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          'Class Teacher: $classTeacher • ID: ${item['id'] ?? 'auto'}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Class',
                          onPressed: () => _showEditClassDialog(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: CURRICULUM SUBJECTS
  // ==========================================

  Widget _buildSubjectsTab() {
    final filtered = _subjects.where((s) {
      if (_selectedClassFilter != 'All') {
        final cId = s['class_id']?.toString() ?? '';
        if (cId != _selectedClassFilter) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        _buildMetricRibbon(
          items: [
            {'label': 'Total Subjects', 'val': '${_subjects.length}', 'icon': Icons.book, 'color': const Color(0xFF3B82F6)},
            {'label': 'Core CBSE Codes', 'val': '${_subjects.where((s) => (s['code'] ?? '').toString().length == 3).length}', 'icon': Icons.code, 'color': const Color(0xFF10B981)},
            {'label': 'Class-Mapped', 'val': '${_subjects.where((s) => s['class_id'] != null).length}', 'icon': Icons.link, 'color': const Color(0xFF8B5CF6)},
            {'label': 'Statutory Syllabi', 'val': '${_subjects.length}', 'icon': Icons.verified_user, 'color': const Color(0xFF0EA5E9)},
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedClassFilter,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Subject Classes')),
                        ..._classes.map((c) {
                          final id = c['id']?.toString() ?? '';
                          final name = c['name']?.toString() ?? id;
                          final sec = c['section']?.toString() ?? '';
                          return DropdownMenuItem(value: id, child: Text('$name ($sec)'));
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClassFilter = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('No subjects found in the curriculum register.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final name = item['name']?.toString() ?? 'Subject';
                    final code = item['code']?.toString() ?? 'SUBJ';
                    final classId = item['class_id']?.toString() ?? 'Universal / All Grades';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: Text(
                            code.length > 3 ? code.substring(0, 3) : code,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          'Subject Code: $code • Target Cohort: $classId',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Subject',
                          onPressed: () => _showEditSubjectDialog(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricRibbon({required List<Map<String, dynamic>> items}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((m) {
          final color = m['color'] as Color;
          return Column(
            children: [
              Row(
                children: [
                  Icon(m['icon'] as IconData, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    m['val'].toString(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                m['label'].toString(),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOGS: CREATE & EDIT
  // ==========================================

  void _showCreateClassDialog() {
    final nameCtrl = TextEditingController(text: 'Class 10');
    final secCtrl = TextEditingController(text: 'A');
    String? selectedTeacher;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Add Class & Section Cohort'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Class Level (e.g. "Class 10", "Class 11-PCM")'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secCtrl,
                decoration: const InputDecoration(labelText: 'Section (e.g. "A", "B", "C")'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Assigned Class Teacher'),
                initialValue: selectedTeacher,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None (Assign Later)')),
                  ..._teachers.map((t) {
                    final uname = t['username']?.toString() ?? '';
                    final name = t['name']?.toString() ?? uname;
                    return DropdownMenuItem(value: uname, child: Text('$name ($uname)'));
                  }),
                ],
                onChanged: (val) => setDState(() => selectedTeacher = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _schoolService.createSchoolClass(
                    name: nameCtrl.text,
                    section: secCtrl.text,
                    classTeacherId: selectedTeacher,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class cohort registered successfully in database!')),
                  );
                  _loadMastersData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save Class'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditClassDialog(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['name']?.toString() ?? '');
    final secCtrl = TextEditingController(text: item['section']?.toString() ?? '');
    String? selectedTeacher = item['class_teacher_id']?.toString();
    bool isActive = item['is_active'] != false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('Edit ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Class Level'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secCtrl,
                decoration: const InputDecoration(labelText: 'Section'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Cohort Active'),
                value: isActive,
                onChanged: (val) => setDState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _schoolService.updateSchoolClass(
                    id: item['id']?.toString() ?? '',
                    name: nameCtrl.text,
                    section: secCtrl.text,
                    classTeacherId: selectedTeacher,
                    isActive: isActive,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class details updated successfully!')),
                  );
                  _loadMastersData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSubjectDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? selectedClass;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Add Curriculum Subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Subject Title (e.g. "Science (086)")'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Statutory Subject Code (e.g. "086", "041")'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Target Class Cohort'),
                initialValue: selectedClass,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Universal (All Classes)')),
                  ..._classes.map((c) {
                    final id = c['id']?.toString() ?? '';
                    final name = c['name']?.toString() ?? id;
                    final sec = c['section']?.toString() ?? '';
                    return DropdownMenuItem(value: id, child: Text('$name ($sec)'));
                  }),
                ],
                onChanged: (val) => setDState(() => selectedClass = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _schoolService.createSchoolSubject(
                    name: nameCtrl.text,
                    code: codeCtrl.text,
                    classId: selectedClass,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subject registered in curriculum master!')),
                  );
                  _loadMastersData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save Subject'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSubjectDialog(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['name']?.toString() ?? '');
    final codeCtrl = TextEditingController(text: item['code']?.toString() ?? '');
    String? selectedClass = item['class_id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('Edit ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Subject Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Subject Code'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _schoolService.updateSchoolSubject(
                    id: item['id']?.toString() ?? '',
                    name: nameCtrl.text,
                    code: codeCtrl.text,
                    classId: selectedClass,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subject details updated!')),
                  );
                  _loadMastersData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
