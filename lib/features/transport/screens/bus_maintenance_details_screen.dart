import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/bus_maintenance_service.dart';

class BusMaintenanceDetailsScreen extends StatefulWidget {
  final String busId;
  final String busNumber;
  final String vehicleNo;

  const BusMaintenanceDetailsScreen({
    super.key,
    required this.busId,
    required this.busNumber,
    required this.vehicleNo,
  });

  @override
  State<BusMaintenanceDetailsScreen> createState() =>
      _BusMaintenanceDetailsScreenState();
}

class _BusMaintenanceDetailsScreenState
    extends State<BusMaintenanceDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _service = BusMaintenanceService();
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _fuelHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final services = await _service.getBusServices(widget.busId);
    final fuel = await _service.getFuelHistory(widget.busId);
    setState(() {
      _services = services;
      _fuelHistory = fuel;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    if (_tabController.index == 0) {
      _showAddServiceDialog();
    } else {
      _showAddFuelDialog();
    }
  }

  Future<void> _showAddServiceDialog() async {
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final typeController = TextEditingController();
    final descController = TextEditingController();
    final costController = TextEditingController();
    File? receiptFile;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Service Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: 'Service Type (e.g. Oil Change)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost (₹)'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'pdf'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setState(() {
                        receiptFile = File(result.files.single.path!);
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(receiptFile != null ? 'Receipt Selected' : 'Upload Receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: receiptFile != null ? Colors.green : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await _service.addService(
                  busId: widget.busId,
                  date: dateController.text,
                  type: typeController.text,
                  description: descController.text,
                  cost: double.tryParse(costController.text) ?? 0,
                  receiptFile: receiptFile,
                );
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddFuelDialog() async {
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final litersController = TextEditingController();
    final costController = TextEditingController();
    final odometerController = TextEditingController();
    File? receiptFile;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Fuel Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: odometerController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Current Odometer (km)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: litersController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fuel Added (Liters)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Cost (₹)'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'pdf'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setState(() {
                        receiptFile = File(result.files.single.path!);
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(receiptFile != null ? 'Receipt Selected' : 'Upload Receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: receiptFile != null ? Colors.green : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await _service.addFuelEntry(
                  busId: widget.busId,
                  date: dateController.text,
                  liters: double.tryParse(litersController.text) ?? 0,
                  cost: double.tryParse(costController.text) ?? 0,
                  odometer: double.tryParse(odometerController.text) ?? 0,
                  receiptFile: receiptFile,
                );
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Bus #${widget.busNumber}'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 4,
          labelColor: const Color(0xFFF59E0B),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'SERVICE HISTORY', icon: Icon(Icons.build)),
            Tab(text: 'FUEL HISTORY', icon: Icon(Icons.local_gas_station)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildServiceTab(),
                _buildFuelTab(),
              ],
            ),
    );
  }

  Widget _buildServiceTab() {
    if (_services.isEmpty) {
      return const Center(child: Text('No service history found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service['service_type'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      '₹${service['cost']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Date: ${service['service_date']}', style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text(service['description'] ?? 'No description'),
                if (service['receipt_url'] != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Logic to view image or PDF, normally launchUrl
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt viewed in full screen.')),
                      );
                    },
                    icon: const Icon(Icons.receipt, size: 16),
                    label: const Text('View Receipt'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuelTab() {
    if (_fuelHistory.isEmpty) {
      return const Center(child: Text('No fuel history found.'));
    }
    
    // Average calculation card
    double totalMileage = 0;
    int mileageCount = 0;
    for (var f in _fuelHistory) {
      if (f['mileage_calculated'] != null) {
        totalMileage += (f['mileage_calculated'] as num).toDouble();
        mileageCount++;
      }
    }
    final avgMileage = mileageCount > 0 ? (totalMileage / mileageCount).toStringAsFixed(2) : 'N/A';

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Avg Mileage', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('$avgMileage km/l', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              Column(
                children: [
                  const Text('Last Odometer', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('${_fuelHistory.first['odometer_reading']} km', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _fuelHistory.length,
            itemBuilder: (context, index) {
              final fuel = _fuelHistory[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF59E0B).withOpacity(0.2),
                    child: const Icon(Icons.local_gas_station, color: Color(0xFFF59E0B)),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${fuel['fuel_liters']} L', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${fuel['cost']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Odo: ${fuel['odometer_reading']} km • Date: ${fuel['fill_date']}'),
                      if (fuel['mileage_calculated'] != null)
                        Text(
                          'Mileage: ${(fuel['mileage_calculated'] as num).toStringAsFixed(2)} km/l',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      if (fuel['receipt_url'] != null)
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.receipt, size: 14),
                          label: const Text('Receipt'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
