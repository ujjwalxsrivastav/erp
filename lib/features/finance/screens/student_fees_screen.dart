import 'package:flutter/material.dart';
import '../services/finance_service.dart';

class StudentFeesScreen extends StatefulWidget {
  final String studentId;
  const StudentFeesScreen({super.key, required this.studentId});

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  final _financeService = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allFees = [];
  List<Map<String, dynamic>> _selectedFees = [];

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() => _isLoading = true);
    final fees = await _financeService.getStudentFees(widget.studentId);
    setState(() {
      _allFees = fees;
      _isLoading = false;
      _selectedFees.clear();
    });
  }

  void _toggleFeeSelection(Map<String, dynamic> fee, bool? selected) {
    if (fee['status'] == 'paid') return; // Cannot select paid fees
    
    setState(() {
      if (selected == true) {
        _selectedFees.add(fee);
      } else {
        _selectedFees.removeWhere((f) => f['id'] == fee['id']);
      }
    });
  }

  Future<void> _processPayment() async {
    if (_selectedFees.isEmpty) return;

    setState(() => _isLoading = true);

    // Simulate payment process delay (like opening a payment gateway)
    await Future.delayed(const Duration(seconds: 2));

    final success = await _financeService.payFees(
      widget.studentId,
      _selectedFees,
      'Online Payment', // Defaulting to online payment
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful!')),
      );
      await _loadFees(); // Refresh fees list
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalToPay = 0;
    for (var fee in _selectedFees) {
      totalToPay += (fee['amount'] as num).toDouble();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('My Fees'),
        backgroundColor: const Color(0xFF3B82F6), // Student blue
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _allFees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _allFees.length,
                    itemBuilder: (context, index) {
                      final fee = _allFees[index];
                      final isPaid = fee['status'] == 'paid';
                      final isSelected = _selectedFees.any((f) => f['id'] == fee['id']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          value: isPaid ? true : isSelected,
                          onChanged: isPaid ? null : (val) => _toggleFeeSelection(fee, val),
                          activeColor: isPaid ? Colors.green : const Color(0xFF3B82F6),
                          checkColor: Colors.white,
                          title: Text(
                            fee['fee_type'] ?? 'Fee',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: isPaid ? TextDecoration.lineThrough : null,
                              color: isPaid ? Colors.grey : Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                isPaid ? 'Status: PAID' : 'Due: ${fee['due_date'] ?? 'N/A'}',
                                style: TextStyle(
                                  color: isPaid ? Colors.green : Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isPaid && fee['transaction_id'] != null)
                                Text('Txn: ${fee['transaction_id']}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          secondary: Text(
                            '₹${fee['amount']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isPaid ? Colors.grey : const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Bottom Payment Bar
                if (_selectedFees.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total to Pay',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '₹${totalToPay.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _processPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Pay Now',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
