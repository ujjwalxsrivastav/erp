import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/admin_service.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();

  // Controllers
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _sectionController = TextEditingController();

  // Dropdowns
  String? _selectedDepartment;
  String? _selectedYear;
  String? _selectedSemester;

  bool _isLoading = false;
  bool _isGeneratingId = false;

  final List<String> _departments = ['CSE', 'ECE', 'ME', 'CE', 'EE'];
  final List<String> _years = ['1', '2', '3', '4'];
  final List<String> _semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fatherNameController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  Future<void> _generateStudentId() async {
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select department first')),
      );
      return;
    }

    setState(() => _isGeneratingId = true);
    try {
      final studentId =
          await _adminService.getNextStudentId(_selectedDepartment!);
      setState(() {
        _studentIdController.text = studentId;
        _passwordController.text = studentId; // Password same as ID
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating ID: $e')),
      );
    } finally {
      setState(() => _isGeneratingId = false);
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await _adminService.addStudent(
        studentId: _studentIdController.text,
        password: _passwordController.text,
        name: _nameController.text,
        fatherName: _fatherNameController.text,
        year: _selectedYear!,
        semester: _selectedSemester!,
        department: _selectedDepartment!,
        section: _sectionController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ ${result['message'] ?? 'Student added successfully!'}'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message'] ?? 'Failed to add student'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Student',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Department Selection (First)
                          const Text(
                            'Department',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDepartment,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.school),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF7C3AED), width: 2),
                              ),
                            ),
                            items: _departments.map((dept) {
                              return DropdownMenuItem(
                                  value: dept, child: Text(dept));
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedDepartment = value);
                              _generateStudentId(); // Auto-generate ID when department selected
                            },
                            validator: (value) =>
                                value == null ? 'Select department' : null,
                          ),

                          const SizedBox(height: 20),

                          // Student ID & Password (Auto-generated)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Student ID',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _studentIdController,
                                      decoration: InputDecoration(
                                        prefixIcon: _isGeneratingId
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                              )
                                            : const Icon(Icons.badge),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value?.isEmpty ?? true
                                              ? 'Required'
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.lock),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value?.isEmpty ?? true
                                              ? 'Required'
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Student Name
                          _buildTextField(
                            controller: _nameController,
                            label: 'Student Name',
                            icon: Icons.person,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),

                          const SizedBox(height: 20),

                          // Father Name
                          _buildTextField(
                            controller: _fatherNameController,
                            label: "Father's Name",
                            icon: Icons.person_outline,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),

                          const SizedBox(height: 20),

                          // Year & Semester
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Year',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedYear,
                                      decoration: InputDecoration(
                                        prefixIcon:
                                            const Icon(Icons.calendar_today),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      items: _years.map((year) {
                                        return DropdownMenuItem(
                                          value: year,
                                          child: Text('Year $year'),
                                        );
                                      }).toList(),
                                      onChanged: (value) =>
                                          setState(() => _selectedYear = value),
                                      validator: (value) =>
                                          value == null ? 'Required' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Semester',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedSemester,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.book),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      items: _semesters.map((sem) {
                                        return DropdownMenuItem(
                                          value: sem,
                                          child: Text('Sem $sem'),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(
                                          () => _selectedSemester = value),
                                      validator: (value) =>
                                          value == null ? 'Required' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Section
                          _buildTextField(
                            controller: _sectionController,
                            label: 'Section',
                            icon: Icons.class_,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),

                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveStudent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'Add Student',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
