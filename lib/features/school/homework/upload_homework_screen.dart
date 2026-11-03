import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UploadHomeworkScreen extends StatefulWidget {
  const UploadHomeworkScreen({super.key});

  @override
  State<UploadHomeworkScreen> createState() => _UploadHomeworkScreenState();
}

class _UploadHomeworkScreenState extends State<UploadHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedSubject = 'Mathematics';
  String _selectedClass = 'Class 10-A';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  bool _isLoading = false;

  final List<String> _subjects = ['Mathematics', 'Science', 'English', 'Hindi', 'History', 'Geography', 'Computer Science'];
  final List<String> _classes = ['Class 6-A', 'Class 6-B', 'Class 7-A', 'Class 8-A', 'Class 9-A', 'Class 10-A', 'Class 10-B'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Homework assigned successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Subject'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: Icon(Icons.book_outlined, color: Color(0xFF3B82F6)),
                  ),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v!),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel('Class / Section'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: Icon(Icons.class_outlined, color: Color(0xFF10B981)),
                  ),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v!),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel('Homework Title'),
              _buildTextField(
                controller: _titleController,
                hint: 'e.g., Chapter 5 Exercise 5.3',
                icon: Icons.title,
                validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Description / Instructions'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Add detailed instructions...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel('Due Date'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFFFF6B6B), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Assigning...' : 'Assign Homework',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        ),
      ),
    );
  }
}

