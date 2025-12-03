import 'package:flutter/material.dart';
import '../../services/hr_service.dart';

class StaffEditScreen extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffEditScreen({super.key, required this.staff});

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen>
    with SingleTickerProviderStateMixin {
  final _hrService = HRService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  // Controllers for Personal Details
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

  // Controllers for Professional Details
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _subjectController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _reportingToController = TextEditingController();

  // Controllers for Education & Experience
  final _qualificationController = TextEditingController();
  final _universityController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceYearsController = TextEditingController();

  // Dropdowns
  String? _selectedGender;
  String? _selectedEmploymentType;
  String? _selectedStatus;

  final List<String> _tabs = [
    'Personal',
    'Professional',
    'Education',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });
    _initializeControllers();
  }

  void _initializeControllers() {
    // Personal Details
    _nameController.text = widget.staff['name'] ?? '';
    _dobController.text = widget.staff['date_of_birth'] ?? '';
    _phoneController.text = widget.staff['phone'] ?? '';
    _emailController.text = widget.staff['email'] ?? '';
    _addressController.text = widget.staff['address'] ?? '';
    _cityController.text = widget.staff['city'] ?? '';
    _stateController.text = widget.staff['state'] ?? '';
    _pincodeController.text = widget.staff['pincode'] ?? '';
    _emergencyNameController.text =
        widget.staff['emergency_contact_name'] ?? '';
    _emergencyPhoneController.text =
        widget.staff['emergency_contact_number'] ?? '';
    _emergencyRelationController.text =
        widget.staff['emergency_contact_relation'] ?? '';

    // Professional Details
    _designationController.text =
        widget.staff['designation'] ?? widget.staff['role'] ?? '';
    _departmentController.text = widget.staff['department'] ?? '';
    _subjectController.text = widget.staff['subject'] ?? '';
    _joiningDateController.text = widget.staff['date_of_joining'] ?? '';
    _reportingToController.text = widget.staff['reporting_to'] ?? '';

    // Education & Experience
    _qualificationController.text = widget.staff['highest_qualification'] ??
        widget.staff['qualification'] ??
        '';
    _universityController.text = widget.staff['university'] ?? '';
    _passingYearController.text =
        widget.staff['passing_year']?.toString() ?? '';
    _specializationController.text = widget.staff['specialization'] ?? '';
    _experienceYearsController.text =
        widget.staff['total_experience_years']?.toString() ?? '';

    // Dropdowns
    _selectedGender = widget.staff['gender'];
    _selectedEmploymentType = widget.staff['employment_type'];
    _selectedStatus = widget.staff['status'] ?? 'Active';
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final employeeId = widget.staff['employee_id'] ?? widget.staff['id'];

      // Prepare data based on current tab
      Map<String, dynamic> updateData = {};

      if (_selectedTabIndex == 0) {
        // Personal Details
        updateData = {
          'name': _nameController.text.trim(),
          'date_of_birth': _dobController.text.trim(),
          'gender': _selectedGender,
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'emergency_contact_name': _emergencyNameController.text.trim(),
          'emergency_contact_number': _emergencyPhoneController.text.trim(),
          'emergency_contact_relation':
              _emergencyRelationController.text.trim(),
        };
      } else if (_selectedTabIndex == 1) {
        // Professional Details
        updateData = {
          'designation': _designationController.text.trim(),
          'department': _departmentController.text.trim(),
          'subject': _subjectController.text.trim(),
          'date_of_joining': _joiningDateController.text.trim(),
          'employment_type': _selectedEmploymentType,
          'reporting_to': _reportingToController.text.trim(),
          'status': _selectedStatus,
        };
      } else if (_selectedTabIndex == 2) {
        // Education & Experience
        updateData = {
          'highest_qualification': _qualificationController.text.trim(),
          'university': _universityController.text.trim(),
          'passing_year': int.tryParse(_passingYearController.text.trim()),
          'specialization': _specializationController.text.trim(),
          'total_experience_years':
              int.tryParse(_experienceYearsController.text.trim()),
        };
      }

      final success = await _hrService.updateStaffPersonalDetails(
        employeeId: employeeId,
        data: updateData,
        updatedBy: 'hr1', // TODO: Get from current user session
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Changes saved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(
            context, true); // Return true to indicate changes were made
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to save changes'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Edit Employee Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF059669),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
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
                        child: Text(
                          _tabs[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
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
                  _buildPersonalDetailsForm(),
                  _buildProfessionalDetailsForm(),
                  _buildEducationForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person,
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
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
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  icon: Icons.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.location_on,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
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
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _pincodeController,
            label: 'Pincode',
            icon: Icons.pin_drop,
          ),
          const SizedBox(height: 24),
          const Text(
            'Emergency Contact',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _emergencyNameController,
            label: 'Contact Name',
            icon: Icons.contact_phone,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Contact Number',
                  icon: Icons.phone_android,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _emergencyRelationController,
                  label: 'Relation',
                  icon: Icons.family_restroom,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalDetailsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _designationController,
            label: 'Designation',
            icon: Icons.work,
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _departmentController,
                  label: 'Department',
                  icon: Icons.business,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _subjectController,
                  label: 'Subject/Specialization',
                  icon: Icons.subject,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _joiningDateController,
            label: 'Date of Joining (YYYY-MM-DD)',
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _selectedEmploymentType,
            label: 'Employment Type',
            icon: Icons.badge,
            items: ['Permanent', 'Contract', 'Visiting', 'Guest'],
            onChanged: (value) =>
                setState(() => _selectedEmploymentType = value),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _reportingToController,
            label: 'Reporting To (Employee ID)',
            icon: Icons.supervisor_account,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _selectedStatus,
            label: 'Status',
            icon: Icons.toggle_on,
            items: ['Active', 'On Leave', 'Resigned', 'Terminated', 'Retired'],
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _qualificationController,
            label: 'Highest Qualification',
            icon: Icons.school,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          _buildTextField(
            controller: _specializationController,
            label: 'Specialization',
            icon: Icons.star,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _experienceYearsController,
            label: 'Total Experience (Years)',
            icon: Icons.work_history,
          ),
        ],
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
          prefixIcon: Icon(icon, color: const Color(0xFF059669)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
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
          prefixIcon: Icon(icon, color: const Color(0xFF059669)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
