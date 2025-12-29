import 'package:flutter/material.dart';
import '../services/lead_service.dart';

/// Lead Capture Screen - Public form for college website
/// Students can submit their interest through this form
class LeadCaptureScreen extends StatefulWidget {
  const LeadCaptureScreen({super.key});

  @override
  State<LeadCaptureScreen> createState() => _LeadCaptureScreenState();
}

class _LeadCaptureScreenState extends State<LeadCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final LeadService _leadService = LeadService();

  // Form fields
  String _name = '';
  String _phone = '';
  String _email = '';
  String _city = '';
  String _state = 'Himachal Pradesh';
  String _course = 'BCA';
  String _batch = 'Morning';

  bool _isSubmitting = false;
  bool _isSuccess = false;

  final List<String> _courses = [
    'BCA',
    'MCA',
    'BBA',
    'MBA',
    'BTech',
    'MTech',
    'BSc',
    'MSc',
    'BA',
    'MA',
    'Other',
  ];

  final List<String> _states = [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _isSuccess ? _buildSuccessView() : _buildFormView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.school,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Start Your Journey',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your details and our team will get in touch with you soon!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Name field
              TextFormField(
                decoration: _inputDecoration(
                  label: 'Full Name',
                  icon: Icons.person,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your name';
                  if (v.length < 2) return 'Name is too short';
                  return null;
                },
                onSaved: (v) => _name = v ?? '',
              ),

              const SizedBox(height: 16),

              // Phone field
              TextFormField(
                decoration: _inputDecoration(
                  label: 'Phone Number',
                  icon: Icons.phone,
                  prefix: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Please enter your phone number';
                  if (v.length < 10) return 'Enter a valid 10-digit number';
                  return null;
                },
                onSaved: (v) => _phone = v ?? '',
              ),

              const SizedBox(height: 16),

              // Email field
              TextFormField(
                decoration: _inputDecoration(
                  label: 'Email (Optional)',
                  icon: Icons.email,
                ),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _email = v ?? '',
              ),

              const SizedBox(height: 16),

              // Course dropdown
              DropdownButtonFormField<String>(
                value: _course,
                decoration: _inputDecoration(
                  label: 'Interested Course',
                  icon: Icons.book,
                ),
                items: _courses.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (v) => _course = v ?? 'BCA',
              ),

              const SizedBox(height: 16),

              // Batch dropdown
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _batch,
                      decoration: _inputDecoration(
                        label: 'Preferred Batch',
                        icon: Icons.schedule,
                      ),
                      items: ['Morning', 'Evening', 'Flexible'].map((b) {
                        return DropdownMenuItem(value: b, child: Text(b));
                      }).toList(),
                      onChanged: (v) => _batch = v ?? 'Morning',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // City and State
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration(
                        label: 'City',
                        icon: Icons.location_city,
                      ),
                      onSaved: (v) => _city = v ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _state,
                      decoration: _inputDecoration(
                        label: 'State',
                        icon: Icons.map,
                      ),
                      items: _states.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (v) => _state = v ?? 'Himachal Pradesh',
                      isExpanded: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send),
                            SizedBox(width: 8),
                            Text(
                              'Submit Inquiry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Privacy note
              Center(
                child: Text(
                  'By submitting, you agree to be contacted by our admission team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success animation
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green.shade400,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Thank You!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Your inquiry has been submitted successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Our team will call you within 24 hours',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.badge, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'A dedicated counsellor will be assigned',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isSuccess = false;
                    _formKey.currentState?.reset();
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit Another Inquiry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      prefixText: prefix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      final lead = await _leadService.createLead(
        studentName: _name,
        phone: _phone,
        email: _email.isNotEmpty ? _email : null,
        city: _city.isNotEmpty ? _city : null,
        state: _state,
        preferredCourse: _course,
        preferredBatch: _batch,
        source: 'website',
      );

      if (lead != null) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = true;
        });
      } else {
        _showError('Failed to submit. Please try again.');
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    }

    setState(() => _isSubmitting = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
