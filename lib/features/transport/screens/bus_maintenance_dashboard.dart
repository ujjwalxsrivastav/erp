import 'package:flutter/material.dart';
import '../services/bus_maintenance_service.dart';
import 'bus_maintenance_details_screen.dart';

class BusMaintenanceDashboard extends StatefulWidget {
  const BusMaintenanceDashboard({super.key});

  @override
  State<BusMaintenanceDashboard> createState() => _BusMaintenanceDashboardState();
}

class _BusMaintenanceDashboardState extends State<BusMaintenanceDashboard> {
  final _service = BusMaintenanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    final routes = await _service.getRoutesWithBuses();
    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('Fleet Maintenance'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Select a Route & Bus',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Manage fuel logs, view service history and upload maintenance receipts.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final route = _routes[index];
                        final buses = route['transport_buses'] as List<dynamic>? ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black12,
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: index == 0,
                              iconColor: const Color(0xFFF59E0B),
                              collapsedIconColor: Colors.grey,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.route, color: Color(0xFFF59E0B)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          route['route_name'] ?? 'Unknown Route',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          '${buses.length} Buses active',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                if (buses.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Text('No buses assigned to this route.'),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: buses.length,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemBuilder: (context, busIndex) {
                                      final bus = buses[busIndex];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          leading: const Icon(Icons.directions_bus, color: Color(0xFF1E293B)),
                                          title: Text(
                                            'Bus #${bus['bus_number']}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(bus['vehicle_no'] ?? 'Unknown Plate'),
                                          trailing: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFF59E0B),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => BusMaintenanceDetailsScreen(
                                                    busId: bus['id'],
                                                    busNumber: bus['bus_number'].toString(),
                                                    vehicleNo: bus['vehicle_no'] ?? '',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text('Manage'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _routes.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
