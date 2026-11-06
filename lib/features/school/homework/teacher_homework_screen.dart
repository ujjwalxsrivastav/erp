import 'package:flutter/material.dart';

import 'homework_list_screen.dart';

/// Staff homework desk. Access is limited by the guarded staff route and the
/// service rechecks the live role and allotted class before writes.
class TeacherHomeworkScreen extends StatelessWidget {
  const TeacherHomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeworkListScreen();
}
