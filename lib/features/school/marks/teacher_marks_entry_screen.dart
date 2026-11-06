import 'package:flutter/material.dart';

import 'marks_entry_screen.dart';

/// Role-specific route wrapper; class and subject scoping is enforced by the
/// underlying screen and SchoolService before marks can be saved.
class TeacherMarksEntryScreen extends StatelessWidget {
  const TeacherMarksEntryScreen({super.key});

  @override
  Widget build(BuildContext context) => const MarksEntryScreen();
}
