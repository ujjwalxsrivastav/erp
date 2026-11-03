import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import '../../services/hr_service.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _hrService = HRService();
  late TabController _tabController;

  bool _isLoading = false;
  int _selectedTabIndex = 0;

  // Personal Details Controllers
  final _teacherIdController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  // Professional Details Controllers
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _subjectController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _reportingToController = TextEditingController();

  // Education Controllers
  final _qualificationController = TextEditingController();
  final _universityController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceYearsController = TextEditingController();

  // Document Numbers
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  // Dropdowns
  String? _selectedGender;
  String? _selectedEmploymentType = 'Permanent';
  String? _selectedStatus = 'Active';

  final List<String> _tabs = ['Manual Entry', 'CSV Upload'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });
    _loadNextIds();
  }

  Future<void> _loadNextIds() async {
    setState(() => _isLoading = true);
    try {
      final teacherId = await _hrService.getNextTeacherId();
      final employeeId = await _hrService.getNextEmployeeId();

      if (mounted) {
        setState(() {
          _teacherIdController.text = teacherId;
          _employeeIdController.text = employeeId;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading IDs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _teacherIdController.dispose();
    _employeeIdController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _subjectController.dispose();
    _joiningDateController.dispose();
    _reportingToController.dispose();
    _qualificationController.dispose();
    _universityController.dispose();
    _passingYearController.dispose();
    _specializationController.dispose();
    _experienceYearsController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final staffData = {
        'teacher_id': _teacherIdController.text.trim(),
        'employee_id': _employeeIdController.text.trim(),
        'name': _nameController.text.trim(),
        'date_of_birth': _dobController.text.trim().isEmpty
            ? null
            : _dobController.text.trim(),
        'gender': _selectedGender,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'emergency_contact_name': _emergencyNameController.text.trim(),
        'emergency_contact_number': _emergencyPhoneController.text.trim(),
        'emergency_contact_relation': _emergencyRelationController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'subject': _subjectController.text.trim(),
        'date_of_joining': _joiningDateController.text.trim().isEmpty
            ? null
            : _joiningDateController.text.trim(),
        'employment_type': _selectedEmploymentType,
        'reporting_to': _reportingToController.text.trim().isEmpty
            ? null
            : _reportingToController.text.trim(),
        'status': _selectedStatus,
        'highest_qualification': _qualificationController.text.trim(),
        'university': _universityController.text.trim(),
        'passing_year': _passingYearController.text.trim().isEmpty
            ? null
            : int.tryParse(_passingYearController.text.trim()),
        'specialization': _specializationController.text.trim(),
        'total_experience_years': _experienceYearsController.text.trim().isEmpty
            ? null
            : int.tryParse(_experienceYearsController.text.trim()),
        'aadhaar_number': _aadhaarController.text.trim(),
        'pan_number': _panController.text.trim(),
      };

      final result = await _hrService.createStaff(
        staffData: staffData,
        createdBy: 'hr1', // TODO: Get from current user session
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${result['message'] ?? 'Employee added successfully!'}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message'] ?? 'Failed to add employee'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      final bytes = result.files.first.bytes!;
      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty || csvData.length < 2) {
        throw Exception('CSV file is empty or invalid');
      }

      // Skip header row
      int successCount = 0;
      int failCount = 0;

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];

        if (row.length < 15) {
          failCount++;
          continue;
        }

        try {
          final staffData = {
            'teacher_id': row[0].toString(),
            'employee_id': row[1].toString(),
            'name': row[2].toString(),
            'date_of_birth':
                row[3].toString().isEmpty ? null : row[3].toString(),
            'gender': row[4].toString().isEmpty ? null : row[4].toString(),
            'phone': row[5].toString(),
            'email': row[6].toString(),
            'address': row[7].toString(),
            'city': row[8].toString(),
            'state': row[9].toString(),
            'pincode': row[10].toString(),
            'designation': row[11].toString(),
            'department': row[12].toString(),
            'subject': row[13].toString(),
            'date_of_joining':
                row[14].toString().isEmpty ? null : row[14].toString(),
            'employment_type':
                row[15].toString().isEmpty ? 'Permanent' : row[15].toString(),
            'status': 'Active',
            'highest_qualification': row.length > 16 ? row[16].toString() : '',
            'university': row.length > 17 ? row[17].toString() : '',
            'passing_year': row.length > 18 && row[18].toString().isNotEmpty
                ? int.tryParse(row[18].toString())
                : null,
          };

          final result = await _hrService.createStaff(
            staffData: staffData,
            createdBy: 'hr1',
          );

          if (result['success'] == true) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          print('Error adding row $i: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ Uploaded: $successCount successful, $failCount failed'),
          backgroundColor:
              successCount > 0 ? const Color(0xFF059669) : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      if (successCount > 0) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Add New Employee',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF059669),
        elevation: 0,
        actions: [
          if (_selectedTabIndex == 0 && !_isLoading)
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitForm,
              tooltip: 'Save Employee',
            ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = _selectedTabIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _tabController.animateTo(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF059669),
                                  const Color(0xFF10B981),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == 0 ? Icons.edit : Icons.upload_file,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tabs[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildManualEntryForm(),
                _buildCSVUploadTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-generated IDs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: const Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Auto-generated IDs (Editable)',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _teacherIdController,
                          label: 'Teacher ID',
                          icon: Icons.badge,
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _employeeIdController,
                          label: 'Employee ID',
                          icon: Icons.badge_outlined,
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Personal Details
            _buildSectionTitle('Personal Details'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _nameController,
              label: 'Full Name *',
              icon: Icons.person,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _dobController,
                    label: 'Date of Birth (YYYY-MM-DD)',
                    icon: Icons.cake,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    value: _selectedGender,
                    label: 'Gender',
                    icon: Icons.wc,
                    items: ['Male', 'Female', 'Other'],
                    onChanged: (v) => setState(() => _selectedGender = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _phoneController,
                    label: 'Phone *',
                    icon: Icons.phone,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _emailController,
                    label: 'Email *',
                    icon: Icons.email,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      if (!v!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: 'State',
                    icon: Icons.map,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _pincodeController,
                    label: 'Pincode',
                    icon: Icons.pin_drop,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Emergency Contact',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _emergencyNameController,
                    label: 'Contact Name',
                    icon: Icons.contact_phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _emergencyPhoneController,
                    label: 'Contact Number',
                    icon: Icons.phone_android,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _emergencyRelationController,
              label: 'Relation',
              icon: Icons.family_restroom,
            ),
            const SizedBox(height: 24),

            // Professional Details
            _buildSectionTitle('Professional Details'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _designationController,
                    label: 'Designation *',
                    icon: Icons.work,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _departmentController,
                    label: 'Department *',
                    icon: Icons.business,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _subjectController,
              label: 'Subject/Specialization',
              icon: Icons.subject,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _joiningDateController,
                    label: 'Date of Joining (YYYY-MM-DD)',
                    icon: Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    value: _selectedEmploymentType,
                    label: 'Employment Type',
                    icon: Icons.badge,
                    items: ['Permanent', 'Contract', 'Visiting', 'Guest'],
                    onChanged: (v) =>
                        setState(() => _selectedEmploymentType = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _reportingToController,
                    label: 'Reporting To (Employee ID)',
                    icon: Icons.supervisor_account,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    value: _selectedStatus,
                    label: 'Status',
                    icon: Icons.toggle_on,
                    items: [
                      'Active',
                      'On Leave',
                      'Resigned',
                      'Terminated',
                      'Retired'
                    ],
                    onChanged: (v) => setState(() => _selectedStatus = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Education & Experience
            _buildSectionTitle('Education & Experience'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _qualificationController,
              label: 'Highest Qualification',
              icon: Icons.school,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _universityController,
                    label: 'University',
                    icon: Icons.account_balance,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _passingYearController,
                    label: 'Passing Year',
                    icon: Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _specializationController,
                    label: 'Specialization',
                    icon: Icons.star,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _experienceYearsController,
                    label: 'Total Experience (Years)',
                    icon: Icons.work_history,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Document Numbers
            _buildSectionTitle('Document Numbers'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _aadhaarController,
                    label: 'Aadhaar Number',
                    icon: Icons.credit_card,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _panController,
                    label: 'PAN Number',
                    icon: Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCSVUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Text(
                      'CSV File Format Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your CSV file must have the following columns in this exact order:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildCSVColumn('1', 'teacher_id',
                    'Unique teacher ID (e.g., teacher001)', true),
                _buildCSVColumn('2', 'employee_id',
                    'Unique employee ID (e.g., EMP001)', true),
                _buildCSVColumn('3', 'name', 'Full name', true),
                _buildCSVColumn('4', 'date_of_birth',
                    'Format: YYYY-MM-DD (e.g., 1990-01-15)', false),
                _buildCSVColumn('5', 'gender', 'Male/Female/Other', false),
                _buildCSVColumn('6', 'phone', 'Phone number', true),
                _buildCSVColumn('7', 'email', 'Email address', true),
                _buildCSVColumn('8', 'address', 'Full address', false),
                _buildCSVColumn('9', 'city', 'City name', false),
                _buildCSVColumn('10', 'state', 'State name', false),
                _buildCSVColumn('11', 'pincode', 'Pincode', false),
                _buildCSVColumn('12', 'designation', 'Job title', true),
                _buildCSVColumn('13', 'department', 'Department name', true),
                _buildCSVColumn(
                    '14', 'subject', 'Subject/Specialization', false),
                _buildCSVColumn(
                    '15', 'date_of_joining', 'Format: YYYY-MM-DD', false),
                _buildCSVColumn('16', 'employment_type',
                    'Permanent/Contract/Visiting/Guest', false),
                _buildCSVColumn('17', 'highest_qualification', 'Degree', false),
                _buildCSVColumn('18', 'university', 'University name', false),
                _buildCSVColumn(
                    '19', 'passing_year', 'Year (e.g., 2015)', false),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'First row must be headers. Fields marked with * are required.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Upload Button
          Center(
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    size: 80,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _uploadCSV,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(
                      _isLoading ? 'Uploading...' : 'Select CSV File',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCSVColumn(
      String number, String name, String description, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700),
                    ),
                  TextSpan(
                    text: ' - $description',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF059669), size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(fontSize: 13),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF059669), size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(fontSize: 13),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      ),
    );
  }
}
