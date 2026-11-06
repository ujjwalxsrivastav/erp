import 'package:flutter/material.dart';

import 'add_homework_screen.dart';

/// Staff-only assignment form; createHomework enforces permission and class scope.
class TeacherAddHomeworkScreen extends StatelessWidget {
  const TeacherAddHomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) => const AddHomeworkScreen();
}
