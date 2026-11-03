import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class UploadHomeworkScreen extends StatefulWidget {
  const UploadHomeworkScreen({super.key});

  @override
  State<UploadHomeworkScreen> createState() => _UploadHomeworkScreenState();
}

class _UploadHomeworkScreenState extends State<UploadHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _sectionController = TextEditingController();

  final _schoolService = SchoolService();
  final _authService = AuthService();

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  bool _isLoading = false;
  bool _isInitialising = true;
  String? _selectedFileName;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final classes = await _schoolService.getSchoolClasses();
    final username = await _authService.getCurrentUsername();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _selectedClass = classes.isNotEmpty ? classes.first : null;
      _currentUsername = username;
      _isInitialising = false;
    });
    if (_selectedClass != null) {
      await _loadSubjects();
    }
  }

  Future<void> _loadSubjects() async {
    final classId = _selectedClass?['id']?.toString();
    final subjects = await _schoolService.getSchoolSubjects(classId: classId);
    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
    });
  }

  void _pickFile() {
    // Show indicator without actual storage upload
    setState(() => _selectedFileName = 'homework_attachment.pdf');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File selected: homework_attachment.pdf'),
        backgroundColor: Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class first.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'class_id': _selectedClass!['id']?.toString(),
      'class_name': _selectedClass!['name']?.toString(),
      'subject': _selectedSubject?['name']?.toString() ??
          _selectedSubject?['id']?.toString() ?? '',
      'section': _sectionController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'instructions': _instructionsController.text.trim(),
      'due_date': _dueDate.toIso8601String().substring(0, 10),
      'status': 'pending',
      'teacher': _currentUsername ?? '',
      'created_at': DateTime.now().toIso8601String(),
      if (_selectedFileName != null) 'attachment_name': _selectedFileName,
    };

    final ok = await _schoolService.createHomework(data);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Homework assigned successfully! 🎉'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign homework. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _instructionsController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Assign Homework', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isInitialising
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Class ──
                    _buildLabel('Class *'),
                    _buildCard(
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedClass,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: Icon(Icons.class_outlined, color: Color(0xFF10B981)),
                        ),
                        hint: const Text('Select class'),
                        items: _classes.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c['name']?.toString() ?? c['id']?.toString() ?? ''),
                        )).toList(),
                        validator: (v) => v == null ? 'Please select a class' : null,
                        onChanged: (v) {
                          setState(() => _selectedClass = v);
                          _loadSubjects();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Subject ──
                    _buildLabel('Subject *'),
                    _buildCard(
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedSubject,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: Icon(Icons.book_outlined, color: Color(0xFF3B82F6)),
                        ),
                        hint: const Text('Select subject'),
                        items: _subjects.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s['name']?.toString() ?? s['id']?.toString() ?? ''),
                        )).toList(),
                        validator: (v) => v == null ? 'Please select a subject' : null,
                        onChanged: (v) => setState(() => _selectedSubject = v),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Section ──
                    _buildLabel('Section'),
                    _buildTextField(
                      controller: _sectionController,
                      hint: 'e.g., A',
                      icon: Icons.group_outlined,
                    ),
                    const SizedBox(height: 16),

                    // ── Title ──
                    _buildLabel('Homework Title *'),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'e.g., Chapter 5 Exercise 5.3',
                      icon: Icons.title,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Description ──
                    _buildLabel('Description'),
                    _buildCard(
                      child: TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Brief description of the homework...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Instructions ──
                    _buildLabel('Instructions'),
                    _buildCard(
                      child: TextFormField(
                        controller: _instructionsController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Add detailed step-by-step instructions...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Due Date ──
                    _buildLabel('Due Date *'),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF3B82F6),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      child: _buildCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Color(0xFFFF6B6B), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── File Attachment (optional) ──
                    _buildLabel('Attachment (Optional)'),
                    GestureDetector(
                      onTap: _pickFile,
                      child: _buildCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                _selectedFileName != null
                                    ? Icons.insert_drive_file_outlined
                                    : Icons.attach_file,
                                color: const Color(0xFF3B82F6),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedFileName ?? 'Tap to attach a file',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedFileName != null
                                        ? const Color(0xFF1F2937)
                                        : Colors.grey.shade500,
                                    fontWeight: _selectedFileName != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedFileName != null)
                                GestureDetector(
                                  onTap: () => setState(() => _selectedFileName = null),
                                  child: const Icon(Icons.close,
                                      size: 18, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Submit Button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Assigning...' : 'Assign Homework',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          disabledBackgroundColor:
                              const Color(0xFF3B82F6).withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151)),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return _buildCard(
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        ),
      ),
    );
  }
}
