import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/school_service.dart';
import 'services/user_management_service.dart';

/// Admin — Add User. Creates a login account for a student, teacher or
/// admin and stores the person's name on their profile row.
class AddUserScreen extends StatefulWidget {
  /// Institution the account is created in; returned to the caller on success.
  final String? institution;

  const AddUserScreen({super.key, this.institution});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = UserManagementService();
  final _schoolService = SchoolService();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _subjectController = TextEditingController();
  final _departmentController = TextEditingController();
  final _rollNumberController = TextEditingController();

  String _role = UserRoles.student;
  String? _className;
  List<String> _classes = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _usernameController.addListener(_syncSuggestedPassword);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_syncSuggestedPassword);
    for (final c in [
      _nameController,
      _usernameController,
      _passwordController,
      _subjectController,
      _departmentController,
      _rollNumberController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Password defaults to the username (same convention as the seed data),
  /// but stays editable until the admin types their own.
  String _lastSuggestedPassword = '';
  void _syncSuggestedPassword() {
    if (_passwordController.text == _lastSuggestedPassword ||
        _passwordController.text.isEmpty) {
      _lastSuggestedPassword = _usernameController.text.trim();
      _passwordController.text = _lastSuggestedPassword;
    }
  }

  Future<void> _loadClasses() async {
    final classes = await _schoolService.getSchoolClasses();
    if (!mounted) return;
    setState(() {
      _classes = classes
          .map((c) => c['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final result = await _service.createUser(
      username: _usernameController.text,
      password: _passwordController.text,
      name: _nameController.text,
      role: _role,
      className: _className,
      rollNumber: _rollNumberController.text,
      subject: _subjectController.text,
      department: _departmentController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ),
    );
    if (ok) context.pop(widget.institution);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add User'),
        backgroundColor: AppTheme.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.md),
          children: [
            _sectionTitle('Account'),
            _field(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter the full name' : null,
            ),
            _roleSelector(),
            _field(
              controller: _usernameController,
              label: 'User ID (login username)',
              icon: Icons.badge_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              ],
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Enter a user ID';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                  return 'Letters, numbers and underscore only';
                }
                return null;
              },
            ),
            _field(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              validator: (v) => (v ?? '').length < 6
                  ? 'Password must be at least 6 characters'
                  : null,
            ),
            if (_role == UserRoles.teacher) ...[
              _sectionTitle('Teacher Details'),
              _field(
                controller: _subjectController,
                label: 'Subject',
                icon: Icons.menu_book_outlined,
              ),
              _field(
                controller: _departmentController,
                label: 'Department',
                icon: Icons.business_outlined,
              ),
            ],
            if (_role == UserRoles.student) ...[
              _sectionTitle('Student Details'),
              _classSelector(),
              _field(
                controller: _rollNumberController,
                label: 'Roll Number',
                icon: Icons.format_list_numbered_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: AppTheme.lg),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(_isSaving ? 'Creating…' : 'Create User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.md, bottom: AppTheme.sm),
      child: Text(
        text,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.dark,
        ),
      ),
    );
  }

  Widget _roleSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: DropdownButtonFormField<String>(
        initialValue: _role,
        decoration: _decoration('Role', Icons.shield_outlined),
        items: UserRoles.all
            .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text('${UserRoles.label(r)} (${r})'),
                ))
            .toList(),
        onChanged: (v) => setState(() => _role = v ?? UserRoles.student),
      ),
    );
  }

  Widget _classSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: DropdownButtonFormField<String>(
        initialValue: _className,
        isExpanded: true,
        decoration: _decoration('Class', Icons.school_outlined),
        items: [
          for (final c in _classes)
            DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => setState(() => _className = v),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: _decoration(label, icon),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
    );
  }
}
