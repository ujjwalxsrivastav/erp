import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text(
                'Shivalik ERP',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(title: Text('Dashboard')),
            ListTile(title: Text('Students')),
            ListTile(title: Text('Faculty')),
            ListTile(title: Text('Attendance')),
            ListTile(title: Text('Marks')),
            ListTile(title: Text('Fees')),
          ],
        ),
      ),
      appBar: AppBar(title: const Text("Dashboard")),
      body: const Center(child: Text("Dashboard will come here")),
    );
  }
}
