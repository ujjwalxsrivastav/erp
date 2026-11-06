import 'package:flutter/material.dart';

import 'school_ai_assistant_screen.dart';

class FacultyAiScreen extends StatelessWidget {
  const FacultyAiScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) => SchoolAiAssistantScreen(initialTab: initialTab);
}
