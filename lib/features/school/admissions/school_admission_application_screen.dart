import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/school_service.dart';

/// Public admission enquiry / application form.
///
/// Reachable without signing in via `/admissions/school-apply` (linked from the
/// login screen and the admin Admissions Pipeline). Every submission is
/// persisted to `school_admissions`, so the applicant immediately appears in
/// the admin Admissions Pipeline as "Under Review".
class SchoolAdmissionApplicationScreen extends StatefulWidget {
  const SchoolAdmissionApplicationScreen({super.key});

  @override
  State<SchoolAdmissionApplicationScreen> createState() =>
      _SchoolAdmissionApplicationScreenState();
}

class _SchoolAdmissionApplicationScreenState
    extends State<SchoolAdmissionApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolService = SchoolService();

  final _studentNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _previousSchoolController = TextEditingController();
  final _referralController = TextEditingController();

  static const _grades = [
    'Nursery',
    'LKG',
    'UKG',
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
    'Class 11-Science',
    'Class 11-Commerce',
    'Class 11-Arts',
    'Class 12-Science',
    'Class 12-Commerce',
    'Class 12-Arts',
  ];

  String _selectedGrade = 'Class 1';
  String? _gender;
  DateTime? _dob;
  bool _isSubmitting = false;
  bool _submitted = false;
  String _submittedAppNo = '';

  @override
  void dispose() {
    _studentNameController.dispose();
    _parentNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _previousSchoolController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String get _applicationNo {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'SIS/${DateTime.now().year}/${ts.substring(ts.length - 6)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final appNo = _applicationNo;
    final success = await _schoolService.submitAdmission({
      'application_no': appNo,
      'applicant_name': _studentNameController.text.trim(),
      'grade_applying': _selectedGrade,
      'dob': _dob?.toIso8601String().substring(0, 10) ?? '',
      'gender': _gender ?? '',
      'parent_name': _parentNameController.text.trim(),
      'parent_phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'previous_school': _previousSchoolController.text.trim(),
      'referral': _referralController.text.trim(),
      'source': 'public_form',
      'status': 'Under Review',
      'doc_status': 'Pending',
    });

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (success) {
        _submitted = true;
        _submittedAppNo = appNo;
      }
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Application could not be submitted. Please check your connection and try again.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _studentNameController.clear();
    _parentNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();
    _previousSchoolController.clear();
    _referralController.clear();
    setState(() {
      _submitted = false;
      _submittedAppNo = '';
      _gender = null;
      _dob = null;
      _selectedGrade = 'Class 1';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Admission Application',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
            Text(
              'Open to all • No login required',
              style: TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              'Sign in',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _submitted ? _buildConfirmation() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intro hero
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded,
                        color: Color(0xFF2563EB), size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apply for Admission',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Fill in the student and guardian details below. The school office will review your application and contact you.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Student details
            _sectionCard(
              icon: Icons.person_outline_rounded,
              title: 'Student details',
              children: [
                TextFormField(
                  controller: _studentNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Student full name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter the student name.'
                      : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dob ??
                                DateTime.now().subtract(const Duration(days: 365 * 6)),
                            firstDate: DateTime(2005),
                            lastDate: DateTime.now(),
                            helpText: 'Select date of birth',
                          );
                          if (picked != null) setState(() => _dob = picked);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of birth',
                            prefixIcon: Icon(Icons.cake_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _dob == null
                                ? 'Select date'
                                : _dob!.toIso8601String().substring(0, 10),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: _dob == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Applying for class *',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _grades
                      .map((grade) => DropdownMenuItem(
                            value: grade,
                            child: Text(grade),
                          ))
                      .toList(),
                  onChanged: (grade) {
                    if (grade != null) {
                      setState(() => _selectedGrade = grade);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _previousSchoolController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Previous school (optional)',
                    prefixIcon: Icon(Icons.history_edu_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Parent / guardian
            _sectionCard(
              icon: Icons.family_restroom_rounded,
              title: 'Parent / guardian details',
              children: [
                TextFormField(
                  controller: _parentNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Parent / guardian name *',
                    prefixIcon: Icon(Icons.family_restroom_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a parent or guardian name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final phone =
                        (value ?? '').replaceAll(RegExp(r'[\s()+-]'), '');
                    if (phone.length < 7 || phone.length > 15) {
                      return 'Enter a valid phone number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isNotEmpty &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Residential address (optional)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Referral
            _sectionCard(
              icon: Icons.share_rounded,
              title: 'Referral',
              children: [
                TextFormField(
                  controller: _referralController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Referred by (optional)',
                    hintText: 'Name of the person or source that referred you',
                    helperText:
                        'e.g. a current parent, staff member, alumni, or how you heard about us',
                    prefixIcon: Icon(Icons.person_pin_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit application',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'By submitting you agree to be contacted by the school office about this application.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Application submitted',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your application has been sent to the school for review. You will be contacted on the mobile number provided.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Application No: $_submittedAppNo',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Submit another'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign in'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
