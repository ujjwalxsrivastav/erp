import 'package:flutter/material.dart';
import 'circulars_screen.dart';

class StudentCircularsScreen extends StatelessWidget {
  const StudentCircularsScreen({super.key});
  @override
  Widget build(BuildContext context) => const CircularsScreen(readOnly: true);
}
