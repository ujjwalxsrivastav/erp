import 'package:flutter/material.dart';
import '../services/finance_service.dart';

class ManageFeesScreen extends StatefulWidget {
  const ManageFeesScreen({super.key});

  @override
  State<ManageFeesScreen> createState() => _ManageFeesScreenState();
}

class _ManageFeesScreenState extends State<ManageFeesScreen> {
  final _financeService = FinanceService();
  bool _isLoading = false;
  List<String> _departments = [];
  String? _selectedDepartment;
  List<Map<String, dynamic>> _departmentFees = [];

  final _feeTypeController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoading = true);
    final departments = await _financeService.getDepartments();
    setState(() {
      _departments = departments;
      _isLoading = false;
    });
  }

  Future<void> _loadDepartmentFees(String department) async {
    setState(() {
      _selectedDepartment = department;
      _isLoading = true;
    });
    final fees = await _financeService.getDepartmentFees(department);
    setState(() {
      _departmentFees = fees;
      _isLoading = false;
    });
  }

  Future<void> _addFee() async {
    if (_selectedDepartment == null ||
        _feeTypeController.text.isEmpty ||
        _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final success = await _financeService.addFeeToDepartment(
      _selectedDepartment!,
      _feeTypeController.text,
      amount,
      _dueDate?.toIso8601String().split('T')[0],
    );

    if (success) {
      _feeTypeController.clear();
      _amountController.clear();
      setState(() => _dueDate = null);
      await _loadDepartmentFees(_selectedDepartment!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee added successfully to department')),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add fee')),
      );
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Manage Student Fees'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _departments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Department Selection Card
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Department',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            hint: const Text('Choose a department...'),
                            value: _selectedDepartment,
                            items: _departments.map((dept) {
                              return DropdownMenuItem<String>(
                                value: dept,
                                child: Text(dept),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _loadDepartmentFees(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Add Fee Card (Visible only if department selected)
                  if (_selectedDepartment != null)
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Fee for $_selectedDepartment',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _feeTypeController,
                                    decoration: InputDecoration(
                                      labelText: 'Fee Type (e.g. Tuition Fee)',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Amount (₹)',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDueDate(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _dueDate == null
                                            ? 'Select Due Date (Optional)'
                                            : 'Due: ${_dueDate!.toIso8601String().split('T')[0]}',
                                        style: TextStyle(
                                            color: _dueDate == null
                                                ? Colors.grey.shade700
                                                : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _addFee,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : const Text('Add Fee'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Fee Tabular Format
                  if (_selectedDepartment != null)
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'Current Fees Assigned',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                          _isLoading && _departmentFees.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : _departmentFees.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Center(
                                          child: Text('No fees found for this department')),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor:
                                            MaterialStateProperty.all(Colors.grey.shade50),
                                        columns: const [
                                          DataColumn(label: Text('Fee Type')),
                                          DataColumn(label: Text('Amount')),
                                          DataColumn(label: Text('Due Date')),
                                        ],
                                        rows: _departmentFees.map((fee) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(fee['fee_type'] ?? '')),
                                              DataCell(Text('₹${fee['amount']}')),
                                              DataCell(Text(fee['due_date'] ?? 'N/A')),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
