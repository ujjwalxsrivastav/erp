import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditSalaryScreen extends StatefulWidget {
  final Map<String, dynamic> staff;
  final Map<String, dynamic>? salaryData;

  const EditSalaryScreen({
    super.key,
    required this.staff,
    this.salaryData,
  });

  @override
  State<EditSalaryScreen> createState() => _EditSalaryScreenState();
}

class _EditSalaryScreenState extends State<EditSalaryScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _basicSalaryController;
  late TextEditingController _hraController;
  late TextEditingController _travelAllowanceController;
  late TextEditingController _medicalAllowanceController;
  late TextEditingController _specialAllowanceController;
  late TextEditingController _otherAllowancesController;

  late TextEditingController _pfController;
  late TextEditingController _professionalTaxController;
  late TextEditingController _incomeTaxController;
  late TextEditingController _otherDeductionsController;

  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscCodeController;
  late TextEditingController _branchNameController;

  String _paymentMode = 'Bank Transfer';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final salary = widget.salaryData;

    _basicSalaryController = TextEditingController(
      text: (salary?['basic_salary'] ?? 0).toString(),
    );
    _hraController = TextEditingController(
      text: (salary?['hra'] ?? 0).toString(),
    );
    _travelAllowanceController = TextEditingController(
      text: (salary?['travel_allowance'] ?? 0).toString(),
    );
    _medicalAllowanceController = TextEditingController(
      text: (salary?['medical_allowance'] ?? 0).toString(),
    );
    _specialAllowanceController = TextEditingController(
      text: (salary?['special_allowance'] ?? 0).toString(),
    );
    _otherAllowancesController = TextEditingController(
      text: (salary?['other_allowances'] ?? 0).toString(),
    );

    _pfController = TextEditingController(
      text: (salary?['provident_fund'] ?? 0).toString(),
    );
    _professionalTaxController = TextEditingController(
      text: (salary?['professional_tax'] ?? 0).toString(),
    );
    _incomeTaxController = TextEditingController(
      text: (salary?['income_tax'] ?? 0).toString(),
    );
    _otherDeductionsController = TextEditingController(
      text: (salary?['other_deductions'] ?? 0).toString(),
    );

    _bankNameController = TextEditingController(
      text: salary?['bank_name'] ?? '',
    );
    _accountNumberController = TextEditingController(
      text: salary?['account_number'] ?? '',
    );
    _ifscCodeController = TextEditingController(
      text: salary?['ifsc_code'] ?? '',
    );
    _branchNameController = TextEditingController(
      text: salary?['branch_name'] ?? '',
    );

    _paymentMode = salary?['payment_mode'] ?? 'Bank Transfer';
  }

  @override
  void dispose() {
    _basicSalaryController.dispose();
    _hraController.dispose();
    _travelAllowanceController.dispose();
    _medicalAllowanceController.dispose();
    _specialAllowanceController.dispose();
    _otherAllowancesController.dispose();
    _pfController.dispose();
    _professionalTaxController.dispose();
    _incomeTaxController.dispose();
    _otherDeductionsController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final employeeId = widget.staff['employee_id'];

      final salaryData = {
        'employee_id': employeeId,
        'basic_salary': double.parse(_basicSalaryController.text),
        'hra': double.parse(_hraController.text),
        'travel_allowance': double.parse(_travelAllowanceController.text),
        'medical_allowance': double.parse(_medicalAllowanceController.text),
        'special_allowance': double.parse(_specialAllowanceController.text),
        'other_allowances': double.parse(_otherAllowancesController.text),
        'provident_fund': double.parse(_pfController.text),
        'professional_tax': double.parse(_professionalTaxController.text),
        'income_tax': double.parse(_incomeTaxController.text),
        'other_deductions': double.parse(_otherDeductionsController.text),
        'bank_name': _bankNameController.text.trim(),
        'account_number': _accountNumberController.text.trim(),
        'ifsc_code': _ifscCodeController.text.trim(),
        'branch_name': _branchNameController.text.trim(),
        'payment_mode': _paymentMode,
        'is_active': true,
        'effective_from': DateTime.now().toIso8601String().split('T')[0],
      };

      if (widget.salaryData != null) {
        // Update existing
        await _supabase
            .from('teacher_salary')
            .update(salaryData)
            .eq('employee_id', employeeId)
            .eq('is_active', true);
      } else {
        // Insert new
        await _supabase.from('teacher_salary').insert(salaryData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Salary updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
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
        title: const Text('Edit Salary'),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveSalary,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Employee Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.staff['name']?[0].toUpperCase() ?? 'T',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.staff['name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.staff['role']} • ${widget.staff['department']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Earnings Section
            _buildSectionTitle('Earnings'),
            const SizedBox(height: 12),
            _buildTextField('Basic Salary', _basicSalaryController,
                Icons.account_balance_wallet),
            const SizedBox(height: 12),
            _buildTextField('HRA', _hraController, Icons.home),
            const SizedBox(height: 12),
            _buildTextField('Travel Allowance', _travelAllowanceController,
                Icons.directions_car),
            const SizedBox(height: 12),
            _buildTextField('Medical Allowance', _medicalAllowanceController,
                Icons.medical_services),
            const SizedBox(height: 12),
            _buildTextField(
                'Special Allowance', _specialAllowanceController, Icons.star),
            const SizedBox(height: 12),
            _buildTextField('Other Allowances', _otherAllowancesController,
                Icons.more_horiz),
            const SizedBox(height: 24),

            // Deductions Section
            _buildSectionTitle('Deductions'),
            const SizedBox(height: 12),
            _buildTextField('Provident Fund', _pfController, Icons.savings),
            const SizedBox(height: 12),
            _buildTextField(
                'Professional Tax', _professionalTaxController, Icons.receipt),
            const SizedBox(height: 12),
            _buildTextField(
                'Income Tax', _incomeTaxController, Icons.account_balance),
            const SizedBox(height: 12),
            _buildTextField('Other Deductions', _otherDeductionsController,
                Icons.remove_circle),
            const SizedBox(height: 24),

            // Bank Details Section
            _buildSectionTitle('Bank Details'),
            const SizedBox(height: 12),
            _buildTextField(
                'Bank Name', _bankNameController, Icons.account_balance,
                isNumber: false),
            const SizedBox(height: 12),
            _buildTextField(
                'Account Number', _accountNumberController, Icons.credit_card,
                isNumber: false),
            const SizedBox(height: 12),
            _buildTextField('IFSC Code', _ifscCodeController, Icons.code,
                isNumber: false),
            const SizedBox(height: 12),
            _buildTextField(
                'Branch Name', _branchNameController, Icons.location_on,
                isNumber: false),
            const SizedBox(height: 12),

            // Payment Mode
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Mode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _paymentMode,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['Bank Transfer', 'Cheque', 'Cash', 'UPI']
                        .map((mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(mode),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _paymentMode = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveSalary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF059669)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required';
          }
          if (isNumber && double.tryParse(value) == null) {
            return 'Invalid number';
          }
          return null;
        },
      ),
    );
  }
}
