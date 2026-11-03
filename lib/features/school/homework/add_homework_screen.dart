import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

/// Assign homework for a subject the teacher actually teaches.
///
/// Choices come from the teacher's own timetable entries, so a teacher cannot
/// assign work to another class or subject. The record is written straight to
/// `school_homework` with the teacher's username attached.
class AddHomeworkScreen extends StatefulWidget {
  const AddHomeworkScreen({super.key});

  @override
  State<AddHomeworkScreen> createState() => _AddHomeworkScreenState();
}

class _AddHomeworkScreenState extends State<AddHomeworkScreen> {
  final _schoolService = SchoolService();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _options = [];
  Map<String, dynamic>? _selectedOption;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));

  String _username = '';
  bool _isInitialising = true;
  bool _isSaving = false;

  static const Color _accent = Color(0xFF2563EB);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _username = await _authService.getCurrentUsername() ?? '';
    final options = await _schoolService.getTeacherAssignments(_username);

    if (!mounted) return;
    setState(() {
      _options = options;
      _selectedOption = options.isNotEmpty ? options.first : null;
      _isInitialising = false;
    });
  }

  String _optionLabel(Map<String, dynamic> option) {
    final className = _schoolService.classDisplayName(
      classId: option['class_id']?.toString(),
      className: option['class_name']?.toString(),
      section: option['section']?.toString(),
    );
    final subject = option['subject']?.toString() ?? 'Subject';
    return className.isEmpty ? subject : '$className · $subject';
  }

  String _payloadClassName() {
    final option = _selectedOption;
    if (option == null) return '';
    final explicit = option['class_name']?.toString() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final classId = option['class_id']?.toString() ?? '';
    final match = RegExp(r'(\d+)').firstMatch(classId);
    return match != null ? 'Class ${match.group(1)}' : classId;
  }

  String _payloadSection() {
    final option = _selectedOption;
    if (option == null) return '';
    final explicit = option['section']?.toString() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final classId = option['class_id']?.toString() ?? '';
    final match =
        RegExp(r'^cls-\d+([a-zA-Z])$', caseSensitive: false).firstMatch(classId);
    return (match?.group(1) ?? '').toUpperCase();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOption == null) {
      _showMessage('No subject is assigned to you yet.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final ok = await _schoolService.createHomework({
      'class_id': _selectedOption!['class_id']?.toString(),
      'class_name': _payloadClassName(),
      'section': _payloadSection(),
      'subject': _selectedOption!['subject']?.toString() ?? '',
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'due_date': _dueDate.toIso8601String().substring(0, 10),
      'teacher_username': _username,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      _showMessage('Homework assigned successfully.', isError: false);
      context.pop();
    } else {
      _showMessage('Could not save the homework. Please try again.',
          isError: true);
    }
  }

  void _showMessage(String text, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Add Homework',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
          ),
        ),
      ),
      body: _isInitialising
          ? const Center(
              child: CircularProgressIndicator(color: _accent),
            )
          : _options.isEmpty
              ? _buildNoAssignments()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Class & Subject *'),
                        _card(
                          child: DropdownButtonFormField<Map<String, dynamic>>(
                            initialValue: _selectedOption,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              prefixIcon: Icon(Icons.class_outlined,
                                  color: Color(0xFF10B981)),
                            ),
                            items: _options
                                .map((option) => DropdownMenuItem(
                                      value: option,
                                      child: Text(
                                        _optionLabel(option),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedOption = value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Only the classes and subjects on your timetable are listed.',
                          style: TextStyle(fontSize: 11.5, color: _muted),
                        ),
                        const SizedBox(height: 16),
                        _label('Homework Title *'),
                        _card(
                          child: TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., Chapter 5 Exercise 5.3',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Please enter a title'
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('Description'),
                        _card(
                          child: TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText:
                                  'What should the students do for this homework?',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('Due Date *'),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                          child: _card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Color(0xFFFF6B6B), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_drop_down,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submit,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                            label: Text(
                              _isSaving ? 'Assigning...' : 'Assign Homework',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              disabledBackgroundColor:
                                  _accent.withValues(alpha: 0.6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoAssignments() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'No subjects assigned to you',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Homework can only be added for subjects on your timetable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}
