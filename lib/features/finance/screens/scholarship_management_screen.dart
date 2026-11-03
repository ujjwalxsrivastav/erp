import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/finance_service.dart';

class ScholarshipManagementScreen extends StatefulWidget {
  const ScholarshipManagementScreen({super.key});
  @override
  State<ScholarshipManagementScreen> createState() => _ScholarshipManagementScreenState();
}

class _ScholarshipManagementScreenState extends State<ScholarshipManagementScreen> with SingleTickerProviderStateMixin {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _scholarships = [];
  List<Map<String, dynamic>> _studentScholarships = [];
  late TabController _tabController;

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _scholarships = await _service.getScholarships();
    _studentScholarships = await _service.getStudentScholarships();
    setState(() => _isLoading = false);
  }

  void _showCreateDialog() {
    final nameC = TextEditingController(), valueC = TextEditingController(), descC = TextEditingController();
    String type = 'percentage', category = 'merit';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: _cardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Create Scholarship', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(nameC, 'Scholarship Name', Icons.school_rounded),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(initialValue: type, dropdownColor: _cardBg, style: const TextStyle(color: Colors.white),
            decoration: _dropDecor('Type'), items: ['percentage', 'fixed', 'full'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(), onChanged: (v) => setS(() => type = v!))),
          const SizedBox(width: 12),
          Expanded(child: _field(valueC, type == 'full' ? 'N/A' : 'Value', Icons.money_rounded)),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: category, dropdownColor: _cardBg, style: const TextStyle(color: Colors.white),
          decoration: _dropDecor('Category'), items: ['merit', 'government', 'category', 'employee_ward', 'sports', 'cultural'].map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase().replaceAll('_', ' ')))).toList(), onChanged: (v) => setS(() => category = v!)),
        const SizedBox(height: 12),
        _field(descC, 'Description', Icons.description_rounded),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSec))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primary), onPressed: () async {
          if (nameC.text.isEmpty) return;
          await _service.createScholarship({'name': nameC.text, 'scholarship_type': type, 'value': double.tryParse(valueC.text) ?? 0, 'category': category, 'description': descC.text});
          Navigator.pop(ctx); _load();
        }, child: const Text('Create', style: TextStyle(color: Colors.white))),
      ],
    )));
  }

  InputDecoration _dropDecor(String label) => InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), labelText: label, labelStyle: const TextStyle(color: _textSec));
  Widget _field(TextEditingController c, String label, IconData icon) => TextField(controller: c, style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), labelText: label, labelStyle: const TextStyle(color: _textSec), prefixIcon: Icon(icon, color: _textSec, size: 20)));

  Color _catColor(String c) { switch(c) { case 'merit': return const Color(0xFFFDCB6E); case 'government': return const Color(0xFF74B9FF); case 'sports': return const Color(0xFF00B894); default: return const Color(0xFFA29BFE); } }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Scholarship & Concessions', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard')),
        bottom: TabBar(controller: _tabController, indicatorColor: _primary, labelColor: Colors.white, unselectedLabelColor: _textSec, tabs: const [Tab(text: 'Scholarships'), Tab(text: 'Applications')])),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCreateDialog, backgroundColor: _primary, icon: const Icon(Icons.add, color: Colors.white), label: const Text('New Scholarship', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _primary)) : TabBarView(controller: _tabController, children: [_buildScholarshipsTab(), _buildApplicationsTab()]),
    );
  }

  Widget _buildScholarshipsTab() {
    return _scholarships.isEmpty
      ? const Center(child: Text('No scholarships created', style: TextStyle(color: _textSec)))
      : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _scholarships.length, itemBuilder: (ctx, i) {
          final s = _scholarships[i];
          final cat = s['category'] ?? 'merit';
          final cc = _catColor(cat);
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2D2D44))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: cc.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.school_rounded, color: cc, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cc.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(cat.toUpperCase(), style: TextStyle(color: cc, fontSize: 9, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  Text('${s['scholarship_type']} • ${s['value']}${s['scholarship_type'] == 'percentage' ? '%' : ''}', style: const TextStyle(color: _textSec, fontSize: 11)),
                ]),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: s['is_active'] == true ? const Color(0xFF00B894).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(s['is_active'] == true ? 'Active' : 'Inactive', style: TextStyle(color: s['is_active'] == true ? const Color(0xFF00B894) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
          );
        });
  }

  Widget _buildApplicationsTab() {
    return _studentScholarships.isEmpty
      ? const Center(child: Text('No applications', style: TextStyle(color: _textSec)))
      : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _studentScholarships.length, itemBuilder: (ctx, i) {
          final a = _studentScholarships[i];
          final status = a['status'] ?? 'pending';
          final sc = status == 'approved' ? const Color(0xFF00B894) : status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFFFDCB6E);
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2D2D44))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.person_rounded, color: sc, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['student_id'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Amount: ₹${a['approved_amount'] ?? 0}', style: const TextStyle(color: _textSec, fontSize: 12)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(status.toString().toUpperCase(), style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w700))),
              if (status == 'pending') ...[
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.check_rounded, color: Color(0xFF00B894)), onPressed: () async { await _service.approveScholarship(a['id'], 'accountant1', (a['approved_amount'] as num?)?.toDouble() ?? 0); _load(); }),
              ],
            ]),
          );
        });
  }
}
