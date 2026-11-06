import 'package:flutter/material.dart';

import 'report_card_screen.dart';

/// Staff report-card workspace; access and data scope are enforced by its
/// guarded route and the report-card screen's role-aware loading path.
class StaffReportCardScreen extends StatelessWidget {
  const StaffReportCardScreen({super.key});

  @override
  Widget build(BuildContext context) => const ReportCardScreen();
}
