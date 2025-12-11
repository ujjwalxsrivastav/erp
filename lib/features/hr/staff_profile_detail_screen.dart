import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/staff_pdf_service.dart';
import 'staff_edit_screen.dart';
import 'edit_salary_screen.dart';

class StaffProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffProfileDetailScreen({super.key, required this.staff});

  @override
  State<StaffProfileDetailScreen> createState() =>
      _StaffProfileDetailScreenState();
}

class _StaffProfileDetailScreenState extends State<StaffProfileDetailScreen>
    with SingleTickerProviderStateMixin {
  SupabaseClient get _supabase => Supabase.instance.client;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Salary data
  Map<String, dynamic>? _salaryData;
  bool _isSalaryLoading = true;
  double _leaveDeductions = 0.0;

  final List<String> _tabs = [
    'Personal',
    'Professional',
    'Salary',
    'Documents',
    'Experience',
    'Activity',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    try {
      final employeeId = widget.staff['employee_id'];

      if (employeeId == null) {
        print('Error: employee_id is null in staff data');
        if (mounted) {
          setState(() => _isSalaryLoading = false);
        }
        return;
      }

      // Fetch salary data
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
          .select('deduction_amount')
          .eq('employee_id', employeeId)
          .eq('status', 'Approved')
          .eq('is_salary_deducted', true)
          .gte('start_date', startOfMonth.toIso8601String())
          .lte('start_date', endOfMonth.toIso8601String());

      double totalDeductions = 0.0;
      for (var leave in leaveDeductions) {
        totalDeductions +=
            (leave['deduction_amount'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _salaryData = salaryData;
          _leaveDeductions = totalDeductions;
          _isSalaryLoading = false;
        });
      }
    } catch (e) {
      print('Error loading salary data: $e');
      if (mounted) {
        setState(() => _isSalaryLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Premium Header
          _buildHeader(),

          // Floating Tab Pills
          SliverToBoxAdapter(
            child: _buildTabBar(),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalDetailsTab(),
                _buildProfessionalDetailsTab(),
                _buildSalaryTab(),
                _buildDocumentsTab(),
                _buildExperienceTab(),
                _buildActivityLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF059669),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
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
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Profile Photo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.staff['name']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Text(
                      widget.staff['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    // Role & Department
                    Text(
                      '${widget.staff['role']} • ${widget.staff['department']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    // Employee ID
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.staff['id'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildQuickActionButton(
                          Icons.edit_rounded,
                          'Edit',
                          () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StaffEditScreen(staff: widget.staff),
                              ),
                            );

                            // If changes were made, show success message
                            if (result == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '✅ Profile updated! Please refresh to see changes.'),
                                  backgroundColor: Color(0xFF059669),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildQuickActionButton(
                          Icons.download_rounded,
                          'PDF',
                          () async {
                            // Show loading indicator
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Color(0xFF059669),
                                        ),
                                        SizedBox(height: 16),
                                        Text('Generating PDF...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );

                            try {
                              await StaffPdfService.generateEmployeePdf(
                                  widget.staff);
                              if (!mounted) return;
                              Navigator.pop(context); // Close loading dialog
                            } catch (e) {
                              if (!mounted) return;
                              Navigator.pop(context); // Close loading dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error generating PDF: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildQuickActionButton(
                          Icons.toggle_on_rounded,
                          'Status',
                          () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(6),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isSelected = _selectedTabIndex == index;
            return GestureDetector(
              onTap: () => _tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF059669),
                            const Color(0xFF10B981),
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF059669).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // TAB 1: Personal Details
  Widget _buildPersonalDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                    'Full Name', widget.staff['name'], Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _buildInfoCard('Date of Birth', '15 Jan 1985', Icons.cake),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard('Gender', 'Male', Icons.wc),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                    'Mobile', widget.staff['phone'], Icons.phone),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard('Email', widget.staff['email'], Icons.email),
          const SizedBox(height: 12),
          _buildInfoCard(
            'Address',
            '123, Green Valley, Sector 5, Dehradun, Uttarakhand - 248001',
            Icons.location_on,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                    'Emergency Contact', 'Ravi Kumar', Icons.contact_phone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                    'Contact Number', '+91 98765 00000', Icons.phone_android),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 2: Professional Details
  Widget _buildProfessionalDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _buildProfessionalCard('Designation', widget.staff['role'],
              Icons.work, const Color(0xFF059669)),
          const SizedBox(height: 12),
          _buildProfessionalCard('Department', widget.staff['department'],
              Icons.business, const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _buildProfessionalCard('Date of Joining', '01 Aug 2018',
              Icons.calendar_today, const Color(0xFF8B5CF6)),
          const SizedBox(height: 12),
          _buildProfessionalCard('Employment Type', 'Permanent', Icons.badge,
              const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildProfessionalCard('Reporting To', 'Dr. Sneha Patel (HOD)',
              Icons.supervisor_account, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildProfessionalCard('Employee Code', widget.staff['id'],
              Icons.qr_code, const Color(0xFF6366F1)),
        ],
      ),
    );
  }

  // TAB 3: Salary & Payroll
  Widget _buildSalaryTab() {
    if (_isSalaryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF059669)),
      );
    }

    if (_salaryData == null) {
      return const Center(
        child: Text('No salary data found'),
      );
    }

    final basicSalary =
        (_salaryData!['basic_salary'] as num?)?.toDouble() ?? 0.0;
    final hra = (_salaryData!['hra'] as num?)?.toDouble() ?? 0.0;
    final travelAllowance =
        (_salaryData!['travel_allowance'] as num?)?.toDouble() ?? 0.0;
    final medicalAllowance =
        (_salaryData!['medical_allowance'] as num?)?.toDouble() ?? 0.0;
    final specialAllowance =
        (_salaryData!['special_allowance'] as num?)?.toDouble() ?? 0.0;
    final otherAllowances =
        (_salaryData!['other_allowances'] as num?)?.toDouble() ?? 0.0;

    final pf = (_salaryData!['provident_fund'] as num?)?.toDouble() ?? 0.0;
    final professionalTax =
        (_salaryData!['professional_tax'] as num?)?.toDouble() ?? 0.0;
    final incomeTax = (_salaryData!['income_tax'] as num?)?.toDouble() ?? 0.0;
    final otherDeductions =
        (_salaryData!['other_deductions'] as num?)?.toDouble() ?? 0.0;

    final grossSalary =
        (_salaryData!['gross_salary'] as num?)?.toDouble() ?? 0.0;
    final baseNetSalary =
        (_salaryData!['net_salary'] as num?)?.toDouble() ?? 0.0;
    final finalNetSalary = baseNetSalary - _leaveDeductions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salary & Payroll',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditSalaryScreen(
                        staff: widget.staff,
                        salaryData: _salaryData,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadSalaryData(); // Reload data
                  }
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Net Salary Highlight Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF059669),
                  const Color(0xFF10B981),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  NumberFormat.currency(
                          symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                      .format(finalNetSalary),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _leaveDeductions > 0
                        ? 'After all deductions (incl. ₹${_leaveDeductions.toStringAsFixed(0)} leave deduction)'
                        : 'After all deductions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSalaryDetailCard(
              'Basic Salary',
              NumberFormat.currency(
                      symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                  .format(basicSalary),
              Icons.account_balance_wallet,
              Colors.blue),
          const SizedBox(height: 12),

          _buildSalaryDetailCard(
              'House Rent Allowance',
              NumberFormat.currency(
                      symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                  .format(hra),
              Icons.home,
              Colors.purple),
          const SizedBox(height: 12),

          _buildSalaryDetailCard(
              'Travel Allowance',
              NumberFormat.currency(
                      symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                  .format(travelAllowance),
              Icons.directions_car,
              Colors.orange),
          const SizedBox(height: 12),

          _buildSalaryDetailCard(
              'Medical Allowance',
              NumberFormat.currency(
                      symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                  .format(medicalAllowance),
              Icons.medical_services,
              Colors.red),
          const SizedBox(height: 12),

          if (specialAllowance > 0) ...[
            _buildSalaryDetailCard(
                'Special Allowance',
                NumberFormat.currency(
                        symbol: '₹', locale: 'en_IN', decimalDigits: 0)
                    .format(specialAllowance),
                Icons.star,
                Colors.amber),
            const SizedBox(height: 12),
          ],

          const Divider(height: 32),

          const Text(
            'Deductions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),

          _buildSalaryDetailCard(
              'Provident Fund',
              '- ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(pf)}',
              Icons.savings,
              Colors.red.shade700),
          const SizedBox(height: 12),

          if (professionalTax > 0) ...[
            _buildSalaryDetailCard(
                'Professional Tax',
                '- ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(professionalTax)}',
                Icons.receipt,
                Colors.red.shade700),
            const SizedBox(height: 12),
          ],

          if (_leaveDeductions > 0) ...[
            _buildSalaryDetailCard(
                'Leave Deductions',
                '- ${NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0).format(_leaveDeductions)}',
                Icons.event_busy,
                Colors.red.shade900),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 24),

          const Text(
            'Bank Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard('Bank Name', _salaryData!['bank_name'] ?? 'N/A',
              Icons.account_balance),
          const SizedBox(height: 12),

          _buildInfoCard(
              'Account Number',
              _salaryData!['account_number'] ?? 'N/A',
              Icons.account_balance_wallet),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoCard('IFSC Code',
                    _salaryData!['ifsc_code'] ?? 'N/A', Icons.code),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                    'PAN Number', 'ABCDE1234F', Icons.credit_card),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 4: Documents
  Widget _buildDocumentsTab() {
    final documents = [
      {'name': 'Aadhaar Card', 'icon': Icons.credit_card, 'uploaded': true},
      {
        'name': 'PAN Card',
        'icon': Icons.account_balance_wallet,
        'uploaded': true
      },
      {'name': 'Degree Certificate', 'icon': Icons.school, 'uploaded': true},
      {'name': 'Experience Letter', 'icon': Icons.work, 'uploaded': false},
      {'name': 'Offer Letter', 'icon': Icons.description, 'uploaded': true},
      {'name': 'Joining Letter', 'icon': Icons.assignment, 'uploaded': true},
      {'name': 'Profile Photo', 'icon': Icons.photo, 'uploaded': false},
      {'name': 'Resume/CV', 'icon': Icons.article, 'uploaded': true},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return _buildDocumentCard(
                doc['name'] as String,
                doc['icon'] as IconData,
                doc['uploaded'] as bool,
              );
            },
          ),
        ],
      ),
    );
  }

  // TAB 5: Experience
  Widget _buildExperienceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Education & Experience',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoCard('Highest Qualification', 'Ph.D. in Computer Science',
              Icons.school),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                    'Passing Year', '2015', Icons.calendar_today),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                    'Total Experience', '12 Years', Icons.work_history),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard('University', 'IIT Delhi', Icons.account_balance),
          const SizedBox(height: 24),
          const Text(
            'Work History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildExperienceTimeline(),
        ],
      ),
    );
  }

  Widget _buildExperienceTimeline() {
    final experiences = [
      {
        'company': 'Shivalik College',
        'role': 'Professor',
        'duration': '2018 - Present',
        'color': const Color(0xFF059669),
      },
      {
        'company': 'ABC University',
        'role': 'Associate Professor',
        'duration': '2015 - 2018',
        'color': const Color(0xFF3B82F6),
      },
      {
        'company': 'XYZ Institute',
        'role': 'Assistant Professor',
        'duration': '2012 - 2015',
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Column(
      children: experiences.map((exp) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: exp['color'] as Color,
                      boxShadow: [
                        BoxShadow(
                          color: (exp['color'] as Color).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  if (exp != experiences.last)
                    Container(
                      width: 2,
                      height: 60,
                      color: Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp['role'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exp['company'] as String,
                        style: TextStyle(
                          fontSize: 14,
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
                          color: (exp['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exp['duration'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: exp['color'] as Color,
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
      }).toList(),
    );
  }

  // TAB 6: Activity Logs
  Widget _buildActivityLogsTab() {
    final activities = [
      {
        'title': 'Profile Updated',
        'description': 'Contact information changed',
        'time': '2 hours ago',
        'icon': Icons.edit,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Salary Revised',
        'description': 'Annual increment applied',
        'time': '1 week ago',
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFF059669),
      },
      {
        'title': 'Document Uploaded',
        'description': 'PAN Card uploaded successfully',
        'time': '2 weeks ago',
        'icon': Icons.upload_file,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Status Changed',
        'description': 'Status updated to Active',
        'time': '1 month ago',
        'icon': Icons.toggle_on,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Department Transfer',
        'description': 'Moved to Computer Science',
        'time': '3 months ago',
        'icon': Icons.business,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Timeline',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: activities.map((activity) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                (activity['color'] as Color).withOpacity(0.1),
                            border: Border.all(
                              color: activity['color'] as Color,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            activity['icon'] as IconData,
                            color: activity['color'] as Color,
                            size: 20,
                          ),
                        ),
                        if (activity != activities.last)
                          Container(
                            width: 2,
                            height: 60,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (activity['color'] as Color).withOpacity(0.3),
                                  Colors.grey.shade200,
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (activity['color'] as Color).withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity['title'] as String,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activity['description'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activity['time'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF059669),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryDetailCard(
      String label, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: amount.startsWith('-') ? Colors.red.shade700 : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String name, IconData icon, bool uploaded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: uploaded
              ? const Color(0xFF059669).withOpacity(0.3)
              : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: uploaded
                ? const Color(0xFF059669).withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: uploaded
                  ? const Color(0xFF059669).withOpacity(0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: uploaded ? const Color(0xFF059669) : Colors.grey.shade400,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: uploaded
                  ? const Color(0xFF059669).withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              uploaded ? 'Uploaded' : 'Pending',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: uploaded ? const Color(0xFF059669) : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
