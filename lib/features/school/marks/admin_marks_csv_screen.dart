import 'package:flutter/material.dart';

import 'marks_csv_upload_screen.dart';

/// CSV import is exposed on the admin route only.
class AdminMarksCsvScreen extends StatelessWidget {
  const AdminMarksCsvScreen({super.key});

  @override
  Widget build(BuildContext context) => const MarksCsvUploadScreen();
}
