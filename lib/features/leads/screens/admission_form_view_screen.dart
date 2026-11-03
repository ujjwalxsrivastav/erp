import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admission_form_service.dart';

/// Admission Form View Screen
/// Allows counsellors and deans to view, edit, and verify admission forms
class AdmissionFormViewScreen extends StatefulWidget {
  final String leadId;
  final String? formId;
  final String currentUser;

  const AdmissionFormViewScreen({
    super.key,
    required this.leadId,
    this.formId,
    required this.currentUser,
  });

  @override
  State<AdmissionFormViewScreen> createState() =>
      _AdmissionFormViewScreenState();
}

class _AdmissionFormViewScreenState extends State<AdmissionFormViewScreen> {
  final _formService = AdmissionFormService();
  AdmissionForm? _form;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  final _tenthSchoolController = TextEditingController();
  final _tenthPercentageController = TextEditingController();
  final _twelfthSchoolController = TextEditingController();
  final _twelfthPercentageController = TextEditingController();
  final _verificationNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);

    AdmissionForm? form;
    if (widget.formId != null) {
      form = await _formService.getFormById(widget.formId!);
    } else {
      form = await _formService.getFormByLeadId(widget.leadId);
    }

    if (form != null) {
      _populateControllers(form);
    }

    setState(() {
      _form = form;
      _isLoading = false;
    });
  }

  void _populateControllers(AdmissionForm form) {
    _nameController.text = form.studentName;
    _emailController.text = form.email ?? '';
    _addressController.text = form.address ?? '';
    _fatherNameController.text = form.fatherName ?? '';
    _motherNameController.text = form.motherName ?? '';
    _guardianContactController.text = form.guardianContact ?? '';
    _tenthSchoolController.text = form.tenthSchool ?? '';
    _tenthPercentageController.text = form.tenthPercentage ?? '';
    _twelfthSchoolController.text = form.twelfthSchool ?? '';
    _twelfthPercentageController.text = form.twelfthPercentage ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Form'),
        actions: [
          if (_form != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Form',
            ),
          if (_isEditing)
            TextButton.icon(
              icon: const Icon(Icons.close, color: Colors.white),
              label:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () {
                _populateControllers(_form!);
                setState(() => _isEditing = false);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _form == null
              ? _buildNoFormFound()
              : _buildFormView(),
      bottomNavigationBar: _form != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildNoFormFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Admission Form Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'This lead has not submitted an admission form yet.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(),
          const SizedBox(height: 16),

          // Personal Details
          _buildSectionCard(
            title: '👤 Personal Details',
            children: [
              _buildField('Name', _nameController, enabled: _isEditing),
              _buildField('Email', _emailController, enabled: _isEditing),
              _buildInfoRow('Phone', _form!.phone),
              _buildInfoRow(
                  'DOB', _form!.dob?.toString().split(' ')[0] ?? 'N/A'),
              _buildInfoRow('Gender', _form!.gender ?? 'N/A'),
              _buildInfoRow('Category', _form!.category ?? 'N/A'),
              _buildInfoRow('Aadhar', _form!.aadhar ?? 'N/A'),
              _buildField('Address', _addressController,
                  enabled: _isEditing, maxLines: 2),
              _buildInfoRow('City', _form!.city ?? 'N/A'),
              _buildInfoRow('State', _form!.state ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),

          // Guardian Details
          _buildSectionCard(
            title: '👨‍👩‍👧 Guardian Details',
            children: [
              _buildField("Father's Name", _fatherNameController,
                  enabled: _isEditing),
              _buildInfoRow(
                  "Father's Occupation", _form!.fatherOccupation ?? 'N/A'),
              _buildField("Mother's Name", _motherNameController,
                  enabled: _isEditing),
              _buildInfoRow(
                  "Mother's Occupation", _form!.motherOccupation ?? 'N/A'),
              _buildField('Guardian Contact', _guardianContactController,
                  enabled: _isEditing),
              _buildInfoRow('Guardian Email', _form!.guardianEmail ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),

          // 10th Details
          _buildSectionCard(
            title: '📚 10th Class Details',
            children: [
              _buildField('School', _tenthSchoolController,
                  enabled: _isEditing),
              _buildInfoRow('Board', _form!.tenthBoard ?? 'N/A'),
              _buildInfoRow('Year', _form!.tenthYear?.toString() ?? 'N/A'),
              _buildField('Percentage', _tenthPercentageController,
                  enabled: _isEditing),
              _buildMarksheetRow(
                  '10th Marksheet', _form!.tenthMarksheetUrl, '10th'),
            ],
          ),
          const SizedBox(height: 16),

          // 12th Details
          _buildSectionCard(
            title: '📖 12th Class Details',
            children: [
              _buildField('School', _twelfthSchoolController,
                  enabled: _isEditing),
              _buildInfoRow('Board', _form!.twelfthBoard ?? 'N/A'),
              _buildInfoRow('Stream', _form!.twelfthStream ?? 'N/A'),
              _buildInfoRow('Year', _form!.twelfthYear?.toString() ?? 'N/A'),
              _buildField('Percentage', _twelfthPercentageController,
                  enabled: _isEditing),
              _buildMarksheetRow(
                  '12th Marksheet', _form!.twelfthMarksheetUrl, '12th'),
            ],
          ),
          const SizedBox(height: 16),

          // Course & Payment
          _buildSectionCard(
            title: '🎯 Course & Payment',
            children: [
              _buildInfoRow('Course', _form!.course ?? 'N/A'),
              _buildInfoRow('Session', _form!.session ?? 'N/A'),
              _buildInfoRow('Batch', _form!.batch ?? 'N/A'),
              _buildInfoRow(
                  'Hostel Required', _form!.hostelRequired ? 'Yes ✅' : 'No'),
              _buildInfoRow('Transportation Required',
                  _form!.transportationRequired ? 'Yes ✅' : 'No'),
              const Divider(),
              _buildInfoRow('Payment ID', _form!.paymentId ?? 'N/A'),
              _buildInfoRow(
                  'Payment Status', _form!.paymentStatus.toUpperCase()),
              _buildInfoRow(
                  'Amount Paid', '₹${_form!.paymentAmount.toStringAsFixed(0)}'),
            ],
          ),

          if (_form!.isVerified) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '✅ Verification',
              children: [
                _buildInfoRow('Verified By', _form!.verifiedBy ?? 'N/A'),
                _buildInfoRow('Verified At',
                    _form!.verifiedAt?.toString().split('.')[0] ?? 'N/A'),
                if (_form!.verificationNotes != null)
                  _buildInfoRow('Notes', _form!.verificationNotes!),
              ],
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isVerified = _form!.isVerified;
    final isPaid = _form!.paymentStatus == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVerified
              ? [Colors.green.shade600, Colors.green.shade400]
              : isPaid
                  ? [Colors.blue.shade600, Colors.blue.shade400]
                  : [Colors.orange.shade600, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isVerified
                ? Icons.verified
                : isPaid
                    ? Icons.check_circle
                    : Icons.pending,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified
                      ? 'Form Verified ✓'
                      : isPaid
                          ? 'Payment Completed'
                          : 'Pending Verification',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Submitted: ${_form!.createdAt.toString().split('.')[0]}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool enabled = false,
    int maxLines = 1,
  }) {
    if (!enabled) {
      return _buildInfoRow(
          label, controller.text.isEmpty ? 'N/A' : controller.text);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildMarksheetRow(String label, String? url, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          if (url != null) ...[
            ElevatedButton.icon(
              onPressed: () => _openUrl(url),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (_isEditing)
            OutlinedButton.icon(
              onPressed: () => _reuploadMarksheet(type),
              icon: const Icon(Icons.upload, size: 16),
              label: Text(url != null ? 'Re-upload' : 'Upload'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          if (url == null && !_isEditing)
            const Text('Not uploaded', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reuploadMarksheet(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isSaving = true);

      final file = File(result.files.single.path!);
      final newUrl =
          await _formService.uploadMarksheet(file, _form!.phone, type);

      if (newUrl != null) {
        final fieldName =
            type == '10th' ? 'tenth_marksheet_url' : 'twelfth_marksheet_url';
        await _formService.updateForm(_form!.id, {fieldName: newUrl});
        await _loadForm();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marksheet uploaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to upload marksheet'),
              backgroundColor: Colors.red),
        );
      }

      setState(() => _isSaving = false);
    }
  }

  Widget _buildBottomBar() {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save Changes',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
      );
    }

    if (!_form!.isVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _showVerifyDialog,
            icon: const Icon(Icons.verified_user, color: Colors.white),
            label: const Text('Verify Form',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final updates = {
      'student_name': _nameController.text,
      'email': _emailController.text,
      'address': _addressController.text,
      'father_name': _fatherNameController.text,
      'mother_name': _motherNameController.text,
      'guardian_contact': _guardianContactController.text,
      'tenth_school': _tenthSchoolController.text,
      'tenth_percentage': _tenthPercentageController.text,
      'twelfth_school': _twelfthSchoolController.text,
      'twelfth_percentage': _twelfthPercentageController.text,
    };

    final success = await _formService.updateForm(_form!.id, updates);

    if (success) {
      await _loadForm();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form updated successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to update form'),
            backgroundColor: Colors.red),
      );
    }

    setState(() => _isSaving = false);
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Admission Form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mark this admission form as verified?'),
            const SizedBox(height: 16),
            TextField(
              controller: _verificationNotesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _verifyForm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyForm() async {
    setState(() => _isSaving = true);

    final success = await _formService.verifyForm(
      _form!.id,
      widget.currentUser,
      notes: _verificationNotesController.text.isEmpty
          ? null
          : _verificationNotesController.text,
    );

    if (success) {
      await _loadForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Form verified successfully!'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to verify form'),
            backgroundColor: Colors.red),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _guardianContactController.dispose();
    _tenthSchoolController.dispose();
    _tenthPercentageController.dispose();
    _twelfthSchoolController.dispose();
    _twelfthPercentageController.dispose();
    _verificationNotesController.dispose();
    super.dispose();
  }
}
