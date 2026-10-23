import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/admission_flow_service.dart';

/// Admission Form Screen — in-app version of demo/admissionformdemo.html.
///
/// Five steps: Personal -> Family -> Academic -> Course ->
/// Documents + Review. Every field of the HTML prototype is
/// covered; fields without a dedicated column in
/// `admission_applications` (Aadhaar, parent occupations, guardian
/// email, separate 10th record, stream, batch, hostel/transport,
/// registration fee) are preserved in extra_details (jsonb).
///
/// When opened with a [leadId], the form is prefilled from the
/// lead and the submitted application is linked back to it.
class AdmissionFormScreen extends StatefulWidget {
  final String? leadId;
  final String? leadName;

  const AdmissionFormScreen({super.key, this.leadId, this.leadName});

  @override
  State<AdmissionFormScreen> createState() => _AdmissionFormScreenState();
}

class _AdmissionFormScreenState extends State<AdmissionFormScreen> {
  final _service = AdmissionFlowService();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingLead = false;
  bool _submitted = false;
  String? _applicationNo;
  String? _linkedLeadName;

  final List<GlobalKey<FormState>> _stepKeys = List.generate(
    4,
    (_) => GlobalKey<FormState>(),
  );

  // Step 1 — Personal
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _state;

  // Step 2 — Family
  final _fatherNameController = TextEditingController();
  final _fatherPhoneController = TextEditingController();
  final _fatherOccupationController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _motherOccupationController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  final _guardianEmailController = TextEditingController();
  final _aadhaarController = TextEditingController();
  String _category = 'General';

  // Step 3 — Academic (highest qualification, e.g. 12th)
  final _prevSchoolController = TextEditingController();
  final _percentageController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _tenthSchoolController = TextEditingController();
  final _tenthPercentageController = TextEditingController();
  final _tenthYearController = TextEditingController();
  String? _qualification;
  String? _board;
  String? _stream;
  String? _tenthBoard;

  // Step 4 — Course
  final _branchController = TextEditingController();
  final _sectionController = TextEditingController();
  String? _course;
  String? _department;
  String? _session;
  int _semester = 1;
  String _batch = 'Morning';
  bool _hostelRequired = false;
  bool _transportRequired = false;

  // Step 5 — Documents checklist (keys match the SQL jsonb contract)
  final Map<String, bool> _documents = {
    'photo': false,
    'marksheet': false,
    'tc': false,
    'aadhaar': false,
    'caste_certificate': false,
  };

  static const Map<String, String> _documentLabels = {
    'photo': 'Passport Photo',
    'marksheet': 'Marksheet (10th / 12th)',
    'tc': 'Transfer Certificate (TC)',
    'aadhaar': 'Aadhaar Card',
    'caste_certificate': 'Caste Certificate (if applicable)',
  };

  static const List<String> _courses = [
    'BCA',
    'MCA',
    'BBA',
    'MBA',
    'BTech',
    'MTech',
    'BSc',
    'MSc',
  ];

  static const List<String> _departments = [
    'CSE',
    'ECE',
    'ME',
    'CE',
    'EE',
    'Computer Applications',
    'Management',
    'Basic Sciences',
    'Other',
  ];

  static const List<String> _states = [
    'Himachal Pradesh',
    'Punjab',
    'Haryana',
    'Delhi',
    'Uttarakhand',
    'Uttar Pradesh',
    'Rajasthan',
    'Chandigarh',
    'Jammu & Kashmir',
    'Other',
  ];

  static const List<String> _boards = [
    'CBSE',
    'ICSE',
    'HPBOSE',
    'State Board',
    'Other',
  ];

  static const List<String> _sessions = ['2025-26', '2026-27', '2027-28'];

  @override
  void initState() {
    super.initState();
    _linkedLeadName = widget.leadName;
    if (widget.leadId != null) {
      _loadLead();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _phoneController,
      _altPhoneController,
      _addressController,
      _cityController,
      _pincodeController,
      _fatherNameController,
      _fatherPhoneController,
      _fatherOccupationController,
      _motherNameController,
      _motherOccupationController,
      _guardianNameController,
      _guardianContactController,
      _guardianEmailController,
      _aadhaarController,
      _prevSchoolController,
      _percentageController,
      _passingYearController,
      _tenthSchoolController,
      _tenthPercentageController,
      _tenthYearController,
      _branchController,
      _sectionController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLead() async {
    setState(() => _isLoadingLead = true);
    final lead = await _service.getLead(widget.leadId!);
    if (!mounted) return;
    setState(() => _isLoadingLead = false);
    if (lead == null) return;

    _linkedLeadName = (lead['student_name'] ?? _linkedLeadName)?.toString();
    _nameController.text = (lead['student_name'] ?? '').toString();
    _phoneController.text = (lead['phone'] ?? '').toString();
    _emailController.text = (lead['email'] ?? '').toString();
    _cityController.text = (lead['city'] ?? '').toString();
    if (lead['percentage'] != null) {
      _percentageController.text = lead['percentage'].toString();
    }
    if (lead['passing_year'] != null) {
      _passingYearController.text = lead['passing_year'].toString();
    }
    setState(() {
      final state = lead['state']?.toString();
      if (state != null && _states.contains(state)) _state = state;
      final course = lead['preferred_course']?.toString();
      if (course != null && _courses.contains(course)) _course = course;
      final session = lead['preferred_session']?.toString();
      if (session != null && _sessions.contains(session)) _session = session;
      final qual = lead['qualification']?.toString();
      if (qual != null &&
          ['10th', '12th', 'Diploma', 'Graduate'].contains(qual)) {
        _qualification = qual;
      }
      final batch = lead['preferred_batch']?.toString();
      if (batch != null && ['Morning', 'Evening', 'Flexible'].contains(batch)) {
        _batch = batch;
      }
    });
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2007, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.studentPrimary),
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.studentPrimary, width: 2),
      ),
    );
  }

  Widget _fieldSpacing() => const SizedBox(height: AppTheme.md);

  void _continue() {
    if (_currentStep < 4) {
      if (!(_stepKeys[_currentStep].currentState?.validate() ?? false)) return;
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  String? _nullIfEmpty(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final guardianContact = _nullIfEmpty(_guardianContactController);
    final data = <String, dynamic>{
      'student_name': _nameController.text.trim(),
      'email': _nullIfEmpty(_emailController),
      'phone': _phoneController.text.trim(),
      'alternate_phone':
          _nullIfEmpty(_altPhoneController) ?? guardianContact,
      'date_of_birth': _dob == null ? null : _formatDate(_dob!),
      'gender': _gender,
      'address': _nullIfEmpty(_addressController),
      'city': _nullIfEmpty(_cityController),
      'state': _state,
      'pincode': _nullIfEmpty(_pincodeController),
      'father_name': _nullIfEmpty(_fatherNameController),
      'father_phone':
          _nullIfEmpty(_fatherPhoneController) ?? guardianContact,
      'mother_name': _nullIfEmpty(_motherNameController),
      'guardian_name': _nullIfEmpty(_guardianNameController),
      'category': _category,
      'qualification': _qualification,
      'board': _board,
      'percentage': double.tryParse(_percentageController.text.trim()),
      'passing_year': int.tryParse(_passingYearController.text.trim()),
      'previous_school': _nullIfEmpty(_prevSchoolController),
      'course': _course,
      'department': _department,
      'branch': _nullIfEmpty(_branchController),
      'session': _session,
      'semester': _semester,
      'section': _nullIfEmpty(_sectionController),
      'source': widget.leadId != null ? 'admission_form' : 'walk-in',
      'documents': Map<String, dynamic>.from(_documents),
      'extra_details': <String, dynamic>{
        'aadhaar': _nullIfEmpty(_aadhaarController),
        'father_occupation': _nullIfEmpty(_fatherOccupationController),
        'mother_occupation': _nullIfEmpty(_motherOccupationController),
        'guardian_email': _nullIfEmpty(_guardianEmailController),
        'guardian_contact': guardianContact,
        'stream': _stream,
        'batch': _batch,
        'hostel_required': _hostelRequired,
        'transport_required': _transportRequired,
        'tenth': <String, dynamic>{
          'school': _nullIfEmpty(_tenthSchoolController),
          'board': _tenthBoard,
          'year': int.tryParse(_tenthYearController.text.trim()),
          'percentage': _nullIfEmpty(_tenthPercentageController),
        },
        'registration_fee': 1000,
        'payment_status': 'pending',
      },
    };

    final result =
        await _service.submitAdmissionApplication(data, leadId: widget.leadId);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      setState(() {
        _submitted = true;
        _applicationNo = result['applicationNo']?.toString();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${result['error'] ?? 'unknown'}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Form'),
        foregroundColor: AppTheme.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.studentGradient),
        ),
      ),
      backgroundColor: AppTheme.background,
      body: _submitted
          ? _buildSuccess()
          : Column(
              children: [
                if (_isLoadingLead) const LinearProgressIndicator(),
                if (_linkedLeadName != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(
                        AppTheme.md, AppTheme.md, AppTheme.md, 0),
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                          color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified,
                            color: AppTheme.success, size: 20),
                        const SizedBox(width: AppTheme.sm),
                        Expanded(
                          child: Text(
                            'Linked enquiry: $_linkedLeadName — details '
                            'prefilled from the enquiry.',
                            style: AppTheme.bodyMedium
                                .copyWith(color: AppTheme.dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Stepper(
                    type: StepperType.horizontal,
                    currentStep: _currentStep,
                    onStepContinue: _continue,
                    onStepCancel: _back,
                    onStepTapped: (i) {
                      if (i < _currentStep) setState(() => _currentStep = i);
                    },
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppTheme.lg),
                        child: Row(
                          children: [
                            GradientButton(
                              text: _currentStep == 4
                                  ? 'Submit Application'
                                  : 'Continue',
                              icon: _currentStep == 4
                                  ? Icons.send
                                  : Icons.arrow_forward,
                              gradient: AppTheme.studentGradient,
                              width: 210,
                              height: 50,
                              isLoading: _isSubmitting,
                              onPressed:
                                  _isSubmitting ? () {} : details.onStepContinue!,
                            ),
                            const SizedBox(width: AppTheme.md),
                            if (_currentStep > 0)
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: const Text('Back'),
                              ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title: const Text('Personal'),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepPersonal(),
                      ),
                      Step(
                        title: const Text('Family'),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepFamily(),
                      ),
                      Step(
                        title: const Text('Academic'),
                        isActive: _currentStep >= 2,
                        state: _currentStep > 2
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepAcademic(),
                      ),
                      Step(
                        title: const Text('Course'),
                        isActive: _currentStep >= 3,
                        state: _currentStep > 3
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepCourse(),
                      ),
                      Step(
                        title: const Text('Review'),
                        isActive: _currentStep >= 4,
                        content: _stepReview(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------
  // STEP 1 — Personal (admissionformdemo: Personal Details)
  // ------------------------------------------------------------
  Widget _stepPersonal() {
    return Form(
      key: _stepKeys[0],
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _decoration('Full Name *', Icons.person),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Enter full name' : null,
          ),
          _fieldSpacing(),
          TextFormField(
            controller: _emailController,
            decoration: _decoration('Email *', Icons.email),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Enter email';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  decoration: _decoration('Phone Number *', Icons.phone),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Enter 10-digit number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _altPhoneController,
                  decoration:
                      _decoration('Alternate Phone', Icons.phone_android),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Enter 10-digit number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: _decoration('Date of Birth *', Icons.cake),
                    child: Text(
                      _dob == null ? 'Select date' : _formatDate(_dob!),
                      style: TextStyle(
                        color: _dob == null
                            ? AppTheme.lightGray
                            : AppTheme.dark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: _decoration('Gender *', Icons.wc),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'Select gender' : null,
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          TextFormField(
            controller: _addressController,
            decoration: _decoration('Permanent Address *', Icons.home),
            maxLines: 2,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter address' : null,
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: _decoration('City *', Icons.location_city),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _state,
                  decoration: _decoration('State *', Icons.map),
                  items: _states
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _state = v),
                  validator: (v) => v == null ? 'Select state' : null,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _pincodeController,
                  decoration: _decoration('PIN Code', Icons.pin),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return 'Enter 6-digit PIN';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STEP 2 — Family (admissionformdemo: Guardian Details)
  // ------------------------------------------------------------
  Widget _stepFamily() {
    return Form(
      key: _stepKeys[1],
      child: Column(
        children: [
          TextFormField(
            controller: _fatherNameController,
            decoration:
                _decoration("Father's Name *", Icons.person_outline),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter father name' : null,
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fatherPhoneController,
                  decoration:
                      _decoration("Father's Phone", Icons.phone_in_talk),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Enter 10-digit number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _fatherOccupationController,
                  decoration:
                      _decoration("Father's Occupation", Icons.work_outline),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _motherNameController,
                  decoration:
                      _decoration("Mother's Name *", Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter mother name'
                      : null,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _motherOccupationController,
                  decoration:
                      _decoration("Mother's Occupation", Icons.work_outline),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _guardianNameController,
                  decoration: _decoration('Guardian Name', Icons.shield),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _guardianContactController,
                  decoration:
                      _decoration('Guardian Contact *', Icons.contact_phone),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Enter 10-digit number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          TextFormField(
            controller: _guardianEmailController,
            decoration: _decoration('Guardian Email', Icons.alternate_email),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _decoration('Category', Icons.category),
                  items: const [
                    DropdownMenuItem(
                        value: 'General', child: Text('General')),
                    DropdownMenuItem(value: 'OBC', child: Text('OBC')),
                    DropdownMenuItem(value: 'SC', child: Text('SC')),
                    DropdownMenuItem(value: 'ST', child: Text('ST')),
                    DropdownMenuItem(value: 'EWS', child: Text('EWS')),
                  ],
                  onChanged: (v) =>
                      setState(() => _category = v ?? 'General'),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _aadhaarController,
                  decoration: _decoration('Aadhaar Number', Icons.badge),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    if (!RegExp(r'^\d{12}$').hasMatch(value)) {
                      return 'Enter 12-digit Aadhaar';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STEP 3 — Academic (admissionformdemo: 10th + 12th Details)
  // The 12th / highest record maps to the table columns; the
  // 10th record is preserved in extra_details.tenth.
  // ------------------------------------------------------------
  Widget _stepAcademic() {
    return Form(
      key: _stepKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Highest Qualification (e.g. 12th)',
            style: AppTheme.h5.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _qualification,
                  decoration: _decoration('Qualification *', Icons.school),
                  items: const [
                    DropdownMenuItem(value: '12th', child: Text('12th')),
                    DropdownMenuItem(value: '10th', child: Text('10th')),
                    DropdownMenuItem(
                        value: 'Diploma', child: Text('Diploma')),
                    DropdownMenuItem(
                        value: 'Graduate', child: Text('Graduate')),
                  ],
                  onChanged: (v) => setState(() => _qualification = v),
                  validator: (v) => v == null ? 'Select qualification' : null,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _board,
                  decoration: _decoration('Board *', Icons.menu_book),
                  items: _boards
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _board = v),
                  validator: (v) => v == null ? 'Select board' : null,
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          TextFormField(
            controller: _prevSchoolController,
            decoration: _decoration('School / College Name *', Icons.domain),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter school name' : null,
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _percentageController,
                  decoration: _decoration('Percentage / CGPA *', Icons.percent),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Enter percentage';
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0 || parsed > 100) {
                      return 'Enter 0–100';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _passingYearController,
                  decoration:
                      _decoration('Passing Year *', Icons.calendar_today),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    final parsed = int.tryParse(value);
                    final currentYear = DateTime.now().year;
                    if (parsed == null ||
                        parsed < 1990 ||
                        parsed > currentYear + 1) {
                      return 'Enter a valid year';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _stream,
                  decoration: _decoration('Stream', Icons.alt_route),
                  items: const [
                    DropdownMenuItem(
                        value: 'Science', child: Text('Science (PCM/PCB)')),
                    DropdownMenuItem(
                        value: 'Commerce', child: Text('Commerce')),
                    DropdownMenuItem(
                        value: 'Arts', child: Text('Arts / Humanities')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _stream = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Text(
            '10th Class Details',
            style: AppTheme.h5.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: AppTheme.md),
          TextFormField(
            controller: _tenthSchoolController,
            decoration: _decoration('10th School Name', Icons.domain),
            textCapitalization: TextCapitalization.words,
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _tenthBoard,
                  decoration: _decoration('10th Board', Icons.menu_book),
                  items: _boards
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _tenthBoard = v),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _tenthYearController,
                  decoration: _decoration('10th Passing Year', Icons.event),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _tenthPercentageController,
                  decoration:
                      _decoration('10th Percentage / CGPA', Icons.percent),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STEP 4 — Course (admissionformdemo: Course Selection)
  // ------------------------------------------------------------
  Widget _stepCourse() {
    return Form(
      key: _stepKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _course,
                  decoration: _decoration('Preferred Course *', Icons.book),
                  items: _courses
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _course = v),
                  validator: (v) => v == null ? 'Select course' : null,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _session,
                  decoration: _decoration('Session *', Icons.event),
                  items: _sessions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _session = v),
                  validator: (v) => v == null ? 'Select session' : null,
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _department,
                  decoration: _decoration('Department', Icons.business),
                  items: _departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _department = v),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _branchController,
                  decoration: _decoration('Branch', Icons.call_split),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          _fieldSpacing(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _semester,
                  decoration: _decoration('Semester', Icons.layers),
                  items: List.generate(
                    8,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Semester ${i + 1}'),
                    ),
                  ),
                  onChanged: (v) => setState(() => _semester = v ?? 1),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: _sectionController,
                  decoration: _decoration('Section', Icons.class_),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _batch,
                  decoration: _decoration('Preferred Batch', Icons.schedule),
                  items: const [
                    DropdownMenuItem(
                        value: 'Morning', child: Text('Morning')),
                    DropdownMenuItem(
                        value: 'Afternoon', child: Text('Afternoon')),
                    DropdownMenuItem(
                        value: 'Evening', child: Text('Evening')),
                  ],
                  onChanged: (v) => setState(() => _batch = v ?? 'Morning'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Text(
            'Additional Facilities (Optional)',
            style: AppTheme.h5.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: AppTheme.sm),
          SwitchListTile(
            value: _hostelRequired,
            onChanged: (v) => setState(() => _hostelRequired = v),
            title: const Text('Hostel Facility'),
            subtitle: const Text('On-campus hostel accommodation'),
            secondary: const Icon(Icons.home_work,
                color: AppTheme.studentPrimary),
            activeColor: AppTheme.studentPrimary,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _transportRequired,
            onChanged: (v) => setState(() => _transportRequired = v),
            title: const Text('Transportation Facility'),
            subtitle: const Text('College bus / van pickup & drop service'),
            secondary: const Icon(Icons.directions_bus,
                color: AppTheme.studentPrimary),
            activeColor: AppTheme.studentPrimary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STEP 5 — Documents + Review (admissionformdemo summary style)
  // ------------------------------------------------------------
  Widget _stepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents Received',
          style: AppTheme.h5.copyWith(color: AppTheme.dark),
        ),
        const SizedBox(height: AppTheme.sm),
        ..._documents.entries.map(
          (e) => SwitchListTile(
            value: e.value,
            onChanged: (v) => setState(() => _documents[e.key] = v),
            title: Text(_documentLabels[e.key] ?? e.key),
            secondary: Icon(
              e.value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: e.value ? AppTheme.success : AppTheme.lightGray,
            ),
            activeColor: AppTheme.studentPrimary,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: AppTheme.lg),
        Text(
          'Review Application',
          style: AppTheme.h5.copyWith(color: AppTheme.dark),
        ),
        const SizedBox(height: AppTheme.sm),
        GlassCard(
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(
            children: [
              _summaryRow('Name', _nameController.text.trim()),
              _summaryRow('Phone', _phoneController.text.trim()),
              _summaryRow('Email', _emailController.text.trim()),
              _summaryRow(
                  'Date of Birth', _dob == null ? '—' : _formatDate(_dob!)),
              _summaryRow('Category', _category),
              _summaryRow('Course', _course ?? '—'),
              _summaryRow('Department', _department ?? '—'),
              _summaryRow('Session', _session ?? '—'),
              _summaryRow('Semester', '$_semester'),
              _summaryRow(
                'Qualification',
                '${_qualification ?? '—'}'
                '${_board != null ? ' · $_board' : ''}'
                '${_percentageController.text.trim().isNotEmpty ? ' · ${_percentageController.text.trim()}%' : ''}',
              ),
              _summaryRow("Father's Name", _fatherNameController.text.trim()),
              _summaryRow("Mother's Name", _motherNameController.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2D5A87)],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registration Fee',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                '₹1,000 / one-time',
                style: AppTheme.h4.copyWith(color: AppTheme.white),
              ),
              Text(
                'Payable at the admission desk after approval.',
                style: AppTheme.caption.copyWith(color: AppTheme.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.dark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassCard(
            padding: const EdgeInsets.all(AppTheme.xl),
            child: Column(
              children: [
                const Icon(Icons.celebration,
                    size: 72, color: AppTheme.success),
                const SizedBox(height: AppTheme.md),
                Text(
                  'Application Submitted Successfully!',
                  textAlign: TextAlign.center,
                  style: AppTheme.h4.copyWith(color: AppTheme.success),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  'Your admission form has been received. Our counsellor '
                  'will contact you within 24–48 hours for the further '
                  'process.',
                  textAlign: TextAlign.center,
                  style:
                      AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
                ),
                const SizedBox(height: AppTheme.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.md),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Application Reference',
                        style: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                      const SizedBox(height: AppTheme.xs),
                      Text(
                        _applicationNo ?? '—',
                        style: AppTheme.h4
                            .copyWith(color: AppTheme.studentPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.lg),
                GradientButton(
                  text: 'Done',
                  gradient: AppTheme.studentGradient,
                  width: double.infinity,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
