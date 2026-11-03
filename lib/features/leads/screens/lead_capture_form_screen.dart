import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/admission_flow_service.dart';

/// Lead Capture Form Screen — in-app version of leaddemo.html.
///
/// Used by counsellors / the front desk to log an admission enquiry.
/// Mirrors every field of the HTML prototype (name, phone, email,
/// course, city, state, preferred batch) plus the academic fields
/// the leads table supports (qualification, percentage, passing
/// year, preferred session, source, priority, notes). On submit a
/// row is created in `leads` with status 'new'.
class LeadCaptureFormScreen extends StatefulWidget {
  const LeadCaptureFormScreen({super.key});

  @override
  State<LeadCaptureFormScreen> createState() => _LeadCaptureFormScreenState();
}

class _LeadCaptureFormScreenState extends State<LeadCaptureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AdmissionFlowService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _percentageController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _notesController = TextEditingController();

  String? _course;
  String? _state;
  String _batch = 'Morning';
  String? _qualification;
  String? _session;
  String _source = 'walk-in';
  String _priority = 'normal';

  bool _isSubmitting = false;
  bool _isSuccess = false;
  String _submittedName = '';

  // Course list exactly as in leaddemo.html
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

  // State list exactly as in leaddemo.html
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

  static const List<String> _batches = ['Morning', 'Evening', 'Flexible'];

  static const List<String> _qualifications = [
    '10th',
    '12th',
    'Diploma',
    'Graduate',
    'Post Graduate',
  ];

  static const List<String> _sessions = ['2025-26', '2026-27', '2027-28'];

  static const Map<String, String> _sources = {
    'walk-in': 'Walk-in',
    'website': 'Website',
    'phone': 'Phone Call',
    'referral': 'Referral',
    'social_media': 'Social Media',
    'advertisement': 'Advertisement',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _percentageController.dispose();
    _passingYearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final lead = await _service.createLeadFromEnquiry(
      studentName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      state: _state,
      qualification: _qualification,
      percentage: double.tryParse(_percentageController.text.trim()),
      passingYear: int.tryParse(_passingYearController.text.trim()),
      preferredCourse: _course,
      preferredBatch: _batch,
      preferredSession: _session,
      source: _source,
      priority: _priority,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      enteredBy: 'front_desk',
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (lead != null) {
      setState(() {
        _submittedName = _nameController.text.trim();
        _isSuccess = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the enquiry. Please try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _cityController.clear();
    _percentageController.clear();
    _passingYearController.clear();
    _notesController.clear();
    setState(() {
      _course = null;
      _state = null;
      _batch = 'Morning';
      _qualification = null;
      _session = null;
      _source = 'walk-in';
      _priority = 'normal';
      _isSuccess = false;
      _submittedName = '';
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.studentGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _isSuccess ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.studentPrimary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 44,
                      color: AppTheme.studentPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    'Admission Enquiry',
                    style: AppTheme.h3.copyWith(color: AppTheme.dark),
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    'Start your journey towards success. Fill in the '
                    'details and our admission team will get in touch.',
                    textAlign: TextAlign.center,
                    style:
                        AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.xl),

            TextFormField(
              controller: _nameController,
              decoration: _decoration('Full Name *', Icons.person),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter full name' : null,
            ),
            const SizedBox(height: AppTheme.md),

            TextFormField(
              controller: _phoneController,
              decoration: _decoration('Phone Number *', Icons.phone),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Enter phone number';
                if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                  return 'Enter a valid 10-digit number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.md),

            TextFormField(
              controller: _emailController,
              decoration: _decoration('Email Address', Icons.email),
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
            const SizedBox(height: AppTheme.md),

            DropdownButtonFormField<String>(
              initialValue: _course,
              decoration: _decoration('Interested Course *', Icons.book),
              items: _courses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _course = v),
              validator: (v) => v == null ? 'Select a course' : null,
            ),
            const SizedBox(height: AppTheme.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: _decoration('City', Icons.location_city),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _state,
                    decoration: _decoration('State', Icons.map),
                    items: _states
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _state = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _qualification,
                    decoration: _decoration('Qualification', Icons.school),
                    items: _qualifications
                        .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                        .toList(),
                    onChanged: (v) => setState(() => _qualification = v),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _batch,
                    decoration:
                        _decoration('Preferred Batch', Icons.schedule),
                    items: _batches
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _batch = v ?? 'Morning'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _percentageController,
                    decoration: _decoration('Percentage %', Icons.percent),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
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
                        _decoration('Passing Year', Icons.calendar_today),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
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
              ],
            ),
            const SizedBox(height: AppTheme.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _session,
                    decoration: _decoration('Preferred Session', Icons.event),
                    items: _sessions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _session = v),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: _decoration('Priority', Icons.flag),
                    items: const [
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                    ],
                    onChanged: (v) =>
                        setState(() => _priority = v ?? 'normal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),

            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: _decoration('Enquiry Source', Icons.campaign),
              items: _sources.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _source = v ?? 'walk-in'),
            ),
            const SizedBox(height: AppTheme.md),

            TextFormField(
              controller: _notesController,
              decoration: _decoration('Notes', Icons.note_alt),
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.xl),

            GradientButton(
              text: 'Submit Inquiry',
              icon: Icons.send,
              gradient: AppTheme.studentGradient,
              width: double.infinity,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? () {} : _submit,
            ),
            const SizedBox(height: AppTheme.md),
            Center(
              child: Text(
                'By submitting, you agree to be contacted by our '
                'admission team.',
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(color: AppTheme.lightGray),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.xl),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 44, color: AppTheme.white),
          ),
          const SizedBox(height: AppTheme.lg),
          Text(
            'Thank You!',
            style: AppTheme.h3.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            _submittedName.isEmpty
                ? 'Your inquiry has been submitted successfully.'
                : '$_submittedName, your inquiry has been submitted '
                    'successfully.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
          ),
          const SizedBox(height: AppTheme.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.studentPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              children: [
                _successNote(
                    Icons.call, 'Our team will call you within 24 hours'),
                const SizedBox(height: AppTheme.sm),
                _successNote(Icons.support_agent,
                    'A dedicated counsellor will be assigned to you'),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          OutlinedButton(
            onPressed: _reset,
            child: const Text('Submit Another Inquiry'),
          ),
        ],
      ),
    );
  }

  Widget _successNote(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.studentDark),
        const SizedBox(width: AppTheme.sm),
        Flexible(
          child: Text(
            text,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.studentDark),
          ),
        ),
      ],
    );
  }
}
