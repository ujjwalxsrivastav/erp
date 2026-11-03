import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'edit_salary_screen.dart';

class HRPayrollManagementScreen extends StatefulWidget {
  const HRPayrollManagementScreen({super.key});

  @override
  State<HRPayrollManagementScreen> createState() =>
      _HRPayrollManagementScreenState();
}

class _HRPayrollManagementScreenState extends State<HRPayrollManagementScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading teachers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    return _teachers.where((teacher) {
      final query = _searchQuery.toLowerCase();
      return (teacher['name']?.toString() ?? '')
              .toLowerCase()
              .contains(query) ||
          (teacher['employee_id']?.toString() ?? '')
              .toLowerCase()
              .contains(query) ||
          (teacher['department']?.toString() ?? '')
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF059669),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF059669),
                      const Color(0xFF10B981),
                      const Color(0xFF34D399),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Floating circles
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Payroll Management',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_teachers.length} Teachers',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
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
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, or department...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon:
                                Icon(Icons.clear, color: Colors.grey.shade400),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Teachers List
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF059669),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final teacher = _filteredTeachers[index];
                        return _buildTeacherCard(teacher);
                      },
                      childCount: _filteredTeachers.length,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeacherPayrollDetailScreen(
                  teacher: teacher,
                ),
              ),
            ).then((_) => _loadTeachers()); // Reload on return
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF059669),
                        const Color(0xFF10B981),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      (teacher['name'] ?? 'T')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${teacher['designation'] ?? 'Teacher'} • ${teacher['department'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          teacher['employee_id'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Teacher Payroll Detail Screen
class TeacherPayrollDetailScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherPayrollDetailScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<TeacherPayrollDetailScreen> createState() =>
      _TeacherPayrollDetailScreenState();
}

class _TeacherPayrollDetailScreenState
    extends State<TeacherPayrollDetailScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  Map<String, dynamic>? _salaryData;
  List<Map<String, dynamic>> _leaveDeductions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    try {
      final employeeId = widget.teacher['employee_id'];

      // Fetch salary
      final salaryData = await _supabase
          .from('teacher_salary')
          .select()
          .eq('employee_id', employeeId)
          .eq('is_active', true)
          .maybeSingle();

      // Fetch current month leave deductions
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final leaveDeductions = await _supabase
          .from('teacher_leaves')
          .select()
          .eq('employee_id', employeeId)
          .eq('status', 'Approved')
          .eq('is_salary_deducted', true)
          .gte('start_date', startOfMonth.toIso8601String())
          .lte('start_date', endOfMonth.toIso8601String());

      if (mounted) {
        setState(() {
          _salaryData = salaryData;
          _leaveDeductions = List<Map<String, dynamic>>.from(leaveDeductions);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading salary: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLeaveDeductions = _leaveDeductions.fold(
        0.0, (sum, item) => sum + (item['deduction_amount'] as num).toDouble());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF059669),
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_salaryData != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditSalaryScreen(
                          staff: widget.teacher,
                          salaryData: _salaryData,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadSalaryData();
                    }
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF059669),
                      const Color(0xFF10B981),
                      const Color(0xFF34D399),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (widget.teacher['name'] ?? 'T')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.teacher['name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.teacher['designation']} • ${widget.teacher['department']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF059669),
                      ),
                    ),
                  )
                : _salaryData == null
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_off,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No salary record found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditSalaryScreen(
                                        staff: widget.teacher,
                                        salaryData: null,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadSalaryData();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Salary'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildListDelegate([
                          _buildNetSalaryCard(totalLeaveDeductions),
                          const SizedBox(height: 20),
                          _buildEarningsCard(),
                          const SizedBox(height: 20),
                          _buildDeductionsCard(totalLeaveDeductions),
                          const SizedBox(height: 20),
                          _buildBankDetailsCard(),
                        ]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetSalaryCard(double totalLeaveDeductions) {
    final baseNet = (_salaryData!['net_salary'] as num).toDouble();
    final finalNet = baseNet - totalLeaveDeductions;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Net Monthly Salary',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            NumberFormat.currency(
                    symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                .format(finalNet),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          if (totalLeaveDeductions > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Includes ₹${totalLeaveDeductions.toStringAsFixed(0)} leave deduction',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return _buildCard(
      title: 'Earnings',
      icon: Icons.trending_up,
      iconColor: const Color(0xFF10B981),
      children: [
        _buildRow('Basic Salary', _salaryData!['basic_salary']),
        _buildRow('HRA', _salaryData!['hra']),
        _buildRow('Travel Allowance', _salaryData!['travel_allowance']),
        _buildRow('Medical Allowance', _salaryData!['medical_allowance']),
        if ((_salaryData!['special_allowance'] as num) > 0)
          _buildRow('Special Allowance', _salaryData!['special_allowance']),
        const Divider(height: 24),
        _buildRow('Gross Salary', _salaryData!['gross_salary'], isBold: true),
      ],
    );
  }

  Widget _buildDeductionsCard(double totalLeaveDeductions) {
    return _buildCard(
      title: 'Deductions',
      icon: Icons.trending_down,
      iconColor: const Color(0xFFEF4444),
      children: [
        _buildRow('Provident Fund', _salaryData!['provident_fund']),
        if ((_salaryData!['professional_tax'] as num) > 0)
          _buildRow('Professional Tax', _salaryData!['professional_tax']),
        if (totalLeaveDeductions > 0) ...[
          const SizedBox(height: 12),
          const Text(
            'Leave Deductions:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 8),
          ..._leaveDeductions.map((leave) => _buildLeaveDeductionItem(leave)),
          const SizedBox(height: 8),
          _buildRow('Total Leave Deductions', totalLeaveDeductions,
              isRed: true, isBold: true),
        ],
        const Divider(height: 24),
        _buildRow(
          'Total Deductions',
          (_salaryData!['total_deductions'] as num).toDouble() +
              totalLeaveDeductions,
          isBold: true,
          isRed: true,
        ),
      ],
    );
  }

  Widget _buildLeaveDeductionItem(Map<String, dynamic> leave) {
    final amount = (leave['deduction_amount'] as num).toDouble();
    final totalDays = leave['total_days'] as int;
    final startDate = leave['start_date'] as String;
    final endDate = leave['end_date'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalDays day${totalDays > 1 ? 's' : ''} leave',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startDate to $endDate',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '- ₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard() {
    return _buildCard(
      title: 'Bank Details',
      icon: Icons.account_balance,
      iconColor: const Color(0xFF3B82F6),
      children: [
        _buildInfoRow('Bank Name', _salaryData!['bank_name'] ?? 'N/A'),
        _buildInfoRow(
            'Account Number', _salaryData!['account_number'] ?? 'N/A'),
        _buildInfoRow('IFSC Code', _salaryData!['ifsc_code'] ?? 'N/A'),
        _buildInfoRow('Branch', _salaryData!['branch_name'] ?? 'N/A'),
        _buildInfoRow('Payment Mode', _salaryData!['payment_mode'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, dynamic value,
      {bool isBold = false, bool isRed = false}) {
    final amount = (value is num) ? value.toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            NumberFormat.currency(
                    symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                .format(amount),
            style: TextStyle(
              fontSize: 14,
              color: isRed ? const Color(0xFFEF4444) : const Color(0xFF1F2937),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
