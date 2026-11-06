import 'package:flutter/material.dart';

class HolidayBadge extends StatelessWidget {
  const HolidayBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.beach_access, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

class EventDaySheet extends StatelessWidget {
  const EventDaySheet({super.key, required this.title, required this.count, required this.children});
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Row(children: [const Icon(Icons.event_available, color: Color(0xFF0F766E), size: 20), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))])),
            Text('$count scheduled', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const Divider(height: 20),
          ...children,
        ]),
      );
}
