import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;

class SchoolExportService {
  SchoolExportService._();

  static const PdfColor _primaryTeal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor _darkInk = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _subtleGrey = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _accentGold = PdfColor.fromInt(0xFFD97706);

  // =========================================================================
  // 1. EXPORT CLASS RESULTS (PDF & CSV)
  // =========================================================================

  /// Generates an official Class Merit & Examination Result Register PDF
  static Future<void> exportClassResultsPdf({
    required BuildContext context,
    required String className,
    required String examType,
    required String subjectScope,
    required List<Map<String, dynamic>> students,
    String? topperName,
    double? topperScore,
    double? classAverage,
    int? passedCount,
    int? failCount,
  }) async {
    final doc = pw.Document();
    final dateStr = _currentDate();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _buildPdfHeader(
          title: 'OFFICIAL CLASS MERIT & MARKS REGISTER',
          subtitle: 'Academic Session 2026-2027 · $className · $examType Examination',
        ),
        footer: (ctx) => _buildPdfFooter(ctx, 'Shivalik School Academic Examination Office'),
        build: (ctx) => [
          pw.SizedBox(height: 8),

          // Metadata & Analytics Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Class: $className', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: _darkInk)),
                    pw.Text('Scope: $subjectScope', style: const pw.TextStyle(fontSize: 8.5, color: _subtleGrey)),
                    pw.Text('Date Generated: $dateStr', style: const pw.TextStyle(fontSize: 8, color: _subtleGrey)),
                  ],
                ),
                pw.Row(
                  children: [
                    if (topperName != null && topperName.isNotEmpty) ...[
                      _pdfMetricBox('CLASS TOPPER', '$topperName (${topperScore?.toStringAsFixed(1) ?? "0"}%)', _accentGold),
                      pw.SizedBox(width: 10),
                    ],
                    _pdfMetricBox('CLASS AVERAGE', '${classAverage?.toStringAsFixed(1) ?? "0"}%', _primaryTeal),
                    pw.SizedBox(width: 10),
                    _pdfMetricBox('TOTAL STUDENTS', '${students.length}', _darkInk),
                    pw.SizedBox(width: 10),
                    _pdfMetricBox('PASSED / NEED SUPPORT', '${passedCount ?? students.length} / ${failCount ?? 0}', PdfColors.green800),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Main Roster Table
          pw.TableHelper.fromTextArray(
            headers: ['Rank', 'Roll #', 'Student ID', 'Student Name', 'Marks Obtained', 'Percentage', 'Grade', 'Verdict'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: _primaryTeal),
            cellStyle: const pw.TextStyle(fontSize: 8, color: _darkInk),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
            data: students.map((s) {
              final rank = s['rank']?.toString() ?? '1';
              final roll = s['roll_number']?.toString() ?? '-';
              final id = s['student_id']?.toString() ?? '';
              final name = s['student']?.toString() ?? s['student_name']?.toString() ?? 'Student';
              final marks = (s['marks'] as num?)?.toDouble() ?? 0;
              final maxM = (s['max'] as num?)?.toDouble() ?? 100;
              final pct = (s['pct'] as num?)?.toDouble() ?? 0;
              final grade = s['grade']?.toString() ?? 'D';
              final isPassed = (s['passed'] as bool?) ?? (pct >= 33.0);
              return [
                '#$rank',
                roll,
                id,
                name,
                '${marks.toStringAsFixed(0)} / ${maxM.toStringAsFixed(0)}',
                '${pct.toStringAsFixed(1)}%',
                grade,
                isPassed ? 'PASSED' : 'REMEDIAL',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),

          // Signature blocks
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfSignatureLine('Class Teacher Signature'),
              _pdfSignatureLine('Head of Examination'),
              _pdfSignatureLine('Principal · Seal Verified'),
            ],
          ),
        ],
      ),
    );

    final filename = '${className.replaceAll(" ", "_")}_${examType.replaceAll(" ", "_")}_Merit_Register.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  /// Exports the entire class student result as a CSV string and downloads it
  static Future<void> exportClassResultsCsv({
    required BuildContext context,
    required String className,
    required String examType,
    required String subjectScope,
    required List<Map<String, dynamic>> students,
  }) async {
    final List<List<dynamic>> rows = [
      ['SHIVALIK INTERNATIONAL SCHOOL - OFFICIAL MERIT REGISTER'],
      ['Class', className, 'Exam Term', examType, 'Ranking Scope', subjectScope, 'Generated', _currentDate()],
      [],
      ['Rank', 'Roll Number', 'Student ID', 'Student Name', 'Marks Obtained', 'Total Marks', 'Percentage', 'CBSE Grade', 'Status'],
    ];

    for (final s in students) {
      final rank = s['rank']?.toString() ?? '1';
      final roll = s['roll_number']?.toString() ?? '';
      final id = s['student_id']?.toString() ?? '';
      final name = s['student']?.toString() ?? s['student_name']?.toString() ?? '';
      final marks = (s['marks'] as num?)?.toDouble() ?? 0;
      final maxM = (s['max'] as num?)?.toDouble() ?? 100;
      final pct = (s['pct'] as num?)?.toDouble() ?? 0;
      final grade = s['grade']?.toString() ?? 'D';
      final isPassed = (s['passed'] as bool?) ?? (pct >= 33.0);

      rows.add([
        rank,
        roll,
        id,
        name,
        marks.toStringAsFixed(1),
        maxM.toStringAsFixed(0),
        '${pct.toStringAsFixed(2)}%',
        grade,
        isPassed ? 'PASSED' : 'NEEDS SUPPORT',
      ]);
    }

    final csvContent = const ListToCsvConverter().convert(rows);
    final filename = '${className.replaceAll(" ", "_")}_${examType.replaceAll(" ", "_")}_Results.csv';
    await downloadCsv(context: context, filename: filename, csvContent: csvContent);
  }

  // =========================================================================
  // 2. EXPORT ATTENDANCE (PDF & CSV)
  // =========================================================================

  /// Generates an official Class Attendance Register & Audit Log PDF
  static Future<void> exportAttendancePdf({
    required BuildContext context,
    required String className,
    required DateTime fromDate,
    required DateTime toDate,
    required double overallPct,
    required List<Map<String, dynamic>> attendanceRows,
  }) async {
    final doc = pw.Document();
    final fromStr = _formatDate(fromDate);
    final toStr = _formatDate(toDate);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildPdfHeader(
          title: 'STUDENT ATTENDANCE REGISTER & AUDIT REPORT',
          subtitle: 'Academic Session 2026-2027 · $className · Period $fromStr to $toStr',
        ),
        footer: (ctx) => _buildPdfFooter(ctx, 'Shivalik School Operational Administration'),
        build: (ctx) => [
          pw.SizedBox(height: 10),

          // Summary Strip
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Class Target: $className', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Recorded Working Days: ${attendanceRows.length}', style: const pw.TextStyle(fontSize: 8.5, color: _subtleGrey)),
                  ],
                ),
                _pdfMetricBox(
                  'PERIOD ATTENDANCE',
                  '${overallPct.toStringAsFixed(1)}%',
                  overallPct >= 75 ? PdfColors.green800 : PdfColors.red800,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Attendance Log Table
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Class', 'Present', 'Absent', 'Late', 'Total', 'Attendance Rate'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _primaryTeal),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: _darkInk),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
            },
            data: attendanceRows.map((r) {
              final p = (r['present'] as int?) ?? 0;
              final a = (r['absent'] as int?) ?? 0;
              final l = (r['late'] as int?) ?? 0;
              final tot = (r['total'] as int?) ?? (p + a + l);
              final pct = (r['pct'] as num?)?.toDouble() ?? 0.0;
              return [
                r['date'] ?? '',
                r['class'] ?? className,
                '$p',
                '$a',
                '$l',
                '$tot',
                '${pct.toStringAsFixed(1)}%',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfSignatureLine('Attendance In-Charge'),
              _pdfSignatureLine('Principal · Seal Verified'),
            ],
          ),
        ],
      ),
    );

    final filename = '${className.replaceAll(" ", "_")}_Attendance_Register.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  /// Exports attendance rows as CSV
  static Future<void> exportAttendanceCsv({
    required BuildContext context,
    required String className,
    required DateTime fromDate,
    required DateTime toDate,
    required double overallPct,
    required List<Map<String, dynamic>> attendanceRows,
  }) async {
    final List<List<dynamic>> rows = [
      ['SHIVALIK INTERNATIONAL SCHOOL - ATTENDANCE REGISTER'],
      ['Class', className, 'From', _formatDate(fromDate), 'To', _formatDate(toDate), 'Period Rate', '${overallPct.toStringAsFixed(1)}%'],
      [],
      ['Date', 'Class', 'Present', 'Absent', 'Late', 'Total Marked', 'Attendance Percentage'],
    ];

    for (final r in attendanceRows) {
      final p = (r['present'] as int?) ?? 0;
      final a = (r['absent'] as int?) ?? 0;
      final l = (r['late'] as int?) ?? 0;
      final tot = (r['total'] as int?) ?? (p + a + l);
      final pct = (r['pct'] as num?)?.toDouble() ?? 0.0;

      rows.add([
        r['date'] ?? '',
        r['class'] ?? className,
        p,
        a,
        l,
        tot,
        '${pct.toStringAsFixed(2)}%',
      ]);
    }

    final csvContent = const ListToCsvConverter().convert(rows);
    final filename = '${className.replaceAll(" ", "_")}_Attendance_Log.csv';
    await downloadCsv(context: context, filename: filename, csvContent: csvContent);
  }

  // =========================================================================
  // 3. EXPORT ALL STUDENTS AT PENDING FEES AT ONCE (PDF & CSV)
  // =========================================================================

  /// Generates the Outstanding Fees & Defaulters Ledger PDF for all students
  static Future<void> exportPendingFeesPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> pendingStudents,
    double? totalOutstandingAmount,
  }) async {
    final doc = pw.Document();
    final dateStr = _currentDate();

    double totalDue = 0;
    if (totalOutstandingAmount != null && totalOutstandingAmount > 0) {
      totalDue = totalOutstandingAmount;
    } else {
      for (final s in pendingStudents) {
        totalDue += (s['pending_amount'] as num?)?.toDouble() ??
            (((s['amount'] as num?)?.toDouble() ?? 0) - ((s['paid_amount'] as num?)?.toDouble() ?? 0));
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildPdfHeader(
          title: 'STUDENT OUTSTANDING FEE DEMANDS & DEFAULTERS LEDGER',
          subtitle: 'Academic Session 2026-2027 · Comprehensive Institutional Dues Audit',
        ),
        footer: (ctx) => _buildPdfFooter(ctx, 'Shivalik School Finance & Accounts Department'),
        build: (ctx) => [
          pw.SizedBox(height: 10),

          // Total Dues KPI Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFEF2F2),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFF87171)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('AUDIT DATE: $dateStr', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.red900)),
                    pw.Text('Action: Statutory Fee Recovery Notice Demand', style: const pw.TextStyle(fontSize: 8.5, color: _subtleGrey)),
                  ],
                ),
                pw.Row(
                  children: [
                    _pdfMetricBox('DEFAULTER STUDENTS', '${pendingStudents.length}', PdfColors.red900),
                    pw.SizedBox(width: 14),
                    _pdfMetricBox('TOTAL OUTSTANDING DUES', 'INR ${totalDue.toStringAsFixed(0)}', PdfColors.red900),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Pending Dues Table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Student Name', 'Username / ID', 'Class', 'Total Fee', 'Paid Amount', 'Pending Dues', 'Status'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFB91C1C)),
            cellStyle: const pw.TextStyle(fontSize: 8, color: _darkInk),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
            data: pendingStudents.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final s = entry.value;
              final name = s['name']?.toString() ?? s['student']?.toString() ?? 'Student';
              final user = s['username']?.toString() ?? s['student_id']?.toString() ?? '';
              final cls = s['class_name']?.toString() ?? s['class']?.toString() ?? 'Class 10-A';
              final tot = (s['total_fee'] as num?)?.toDouble() ?? (s['amount'] as num?)?.toDouble() ?? 0;
              final paid = (s['paid_amount'] as num?)?.toDouble() ?? 0;
              final pending = (s['pending_amount'] as num?)?.toDouble() ?? (tot - paid);
              final status = (s['status']?.toString() ?? 'Unpaid').toUpperCase();

              return [
                '$idx',
                name,
                user,
                cls,
                'INR ${tot.toStringAsFixed(0)}',
                'INR ${paid.toStringAsFixed(0)}',
                'INR ${pending.toStringAsFixed(0)}',
                status,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfSignatureLine('Senior Accounts Officer'),
              _pdfSignatureLine('Administrative Officer'),
              _pdfSignatureLine('Principal · Seal Verified'),
            ],
          ),
        ],
      ),
    );

    const filename = 'All_Students_Pending_Fees_Report.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  /// Exports all pending fee students as a CSV file
  static Future<void> exportPendingFeesCsv({
    required BuildContext context,
    required List<Map<String, dynamic>> pendingStudents,
  }) async {
    final List<List<dynamic>> rows = [
      ['SHIVALIK INTERNATIONAL SCHOOL - OUTSTANDING FEES DEFAULTER REGISTER'],
      ['Audit Date', _currentDate(), 'Total Defaulters', pendingStudents.length],
      [],
      ['#', 'Student Name', 'Student Username', 'Class', 'Total Demanded (INR)', 'Paid (INR)', 'Pending Dues (INR)', 'Status'],
    ];

    int idx = 1;
    for (final s in pendingStudents) {
      final name = s['name']?.toString() ?? s['student']?.toString() ?? '';
      final user = s['username']?.toString() ?? s['student_id']?.toString() ?? '';
      final cls = s['class_name']?.toString() ?? s['class']?.toString() ?? '';
      final tot = (s['total_fee'] as num?)?.toDouble() ?? (s['amount'] as num?)?.toDouble() ?? 0;
      final paid = (s['paid_amount'] as num?)?.toDouble() ?? 0;
      final pending = (s['pending_amount'] as num?)?.toDouble() ?? (tot - paid);
      final status = (s['status']?.toString() ?? 'Pending').toUpperCase();

      rows.add([
        idx++,
        name,
        user,
        cls,
        tot.toStringAsFixed(2),
        paid.toStringAsFixed(2),
        pending.toStringAsFixed(2),
        status,
      ]);
    }

    final csvContent = const ListToCsvConverter().convert(rows);
    const filename = 'All_Students_Pending_Fees.csv';
    await downloadCsv(context: context, filename: filename, csvContent: csvContent);
  }

  // =========================================================================
  // 4. COMMON EXPORT DIALOG / MODAL (PDF / CSV / CLIPBOARD)
  // =========================================================================

  /// Shows a clean, modern export chooser modal with options for PDF, CSV, and Excel
  static void showExportOptionsModal({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Future<void> Function() onExportPdf,
    required Future<void> Function() onExportCsv,
    Future<void> Function()? onExportExcel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: Color(0xFF0F766E), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Option 1: PDF Document
              _buildExportActionTile(
                icon: Icons.picture_as_pdf_outlined,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEE2E2),
                title: 'Official Document (PDF)',
                subtitle: 'Print-ready A4 document with official institutional layout & seal',
                badgeText: 'PRINT / PDF',
                onTap: () {
                  Navigator.pop(ctx);
                  onExportPdf();
                },
              ),
              const SizedBox(height: 12),

              // Option 2: CSV Spreadsheet
              _buildExportActionTile(
                icon: Icons.table_view_outlined,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFDCFCE7),
                title: 'Spreadsheet Format (CSV)',
                subtitle: 'Standard CSV data export for Microsoft Excel & Google Sheets',
                badgeText: 'EXCEL / CSV',
                onTap: () {
                  Navigator.pop(ctx);
                  onExportCsv();
                },
              ),
              if (onExportExcel != null) ...[
                const SizedBox(height: 12),
                // Option 3: Excel Workbook (.xlsx)
                _buildExportActionTile(
                  icon: Icons.grid_on_rounded,
                  iconColor: const Color(0xFF107C41),
                  iconBg: const Color(0xFFE6F4EA),
                  title: 'Microsoft Excel (.xlsx)',
                  subtitle: 'Multi-sheet styled workbook with headers, formulas & summary cards',
                  badgeText: 'XLSX / EXCEL',
                  onTap: () {
                    Navigator.pop(ctx);
                    onExportExcel();
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildExportActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badgeText, style: TextStyle(color: iconColor, fontSize: 8.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  static Future<void> downloadCsv({
    required BuildContext context,
    required String filename,
    required String csvContent,
  }) async {
    await Clipboard.setData(ClipboardData(text: csvContent));
    try {
      final bytes = utf8.encode(csvContent);
      final uri = Uri.dataFromBytes(bytes, mimeType: 'text/csv');
      await launchUrl(uri);
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$filename generated and copied to clipboard!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  static pw.Widget _buildPdfHeader({required String title, required String subtitle}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primaryTeal, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SHIVALIK INTERNATIONAL SCHOOL',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: _primaryTeal),
              ),
              pw.SizedBox(height: 2),
              pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _darkInk)),
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 8, color: _subtleGrey)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('CBSE AFFILIATED INSTITUTION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _subtleGrey)),
              pw.Text('OFFICIAL AUDIT REPORT', style: pw.TextStyle(fontSize: 7, color: _primaryTeal, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context ctx, String office) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(office, style: const pw.TextStyle(fontSize: 7, color: _subtleGrey)),
          pw.Text('Generated: ${_currentDate()} · Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _subtleGrey)),
        ],
      ),
    );
  }

  static pw.Widget _pdfMetricBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: color)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: _subtleGrey)),
        ],
      ),
    );
  }

  static pw.Widget _pdfSignatureLine(String label) {
    return pw.Column(
      children: [
        pw.Container(width: 140, height: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _subtleGrey)),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _currentDate() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  // =========================================================================
  // EXCEL (.XLSX) EXPORT METHODS
  // =========================================================================

  static Future<void> downloadExcel({
    required BuildContext context,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final uri = Uri.dataFromBytes(
        bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      await launchUrl(uri);
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$filename downloaded successfully!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Exports the entire class student roster as an official Excel (.xlsx) file (T-R02 format)
  static Future<void> exportClassRosterExcel({
    required BuildContext context,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> students,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary Sheet
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - OFFICIAL CLASS ROSTER')]);
    summarySheet.appendRow([TextCellValue('Class:'), TextCellValue(className)]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Generated Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Total Enrolled Students:'), IntCellValue(students.length)]);
    summarySheet.appendRow([]);

    // Sheet 2: Data Sheet
    final dataSheet = excel['Class Roster'];
    dataSheet.appendRow([
      TextCellValue('Roll Number'),
      TextCellValue('Admission No'),
      TextCellValue('Student Name'),
      TextCellValue('Class & Section'),
      TextCellValue('Parent Name'),
      TextCellValue('Parent Contact'),
      TextCellValue('Attendance %'),
      TextCellValue('Latest Grade'),
    ]);

    for (final s in students) {
      final roll = s['roll_number']?.toString() ?? '-';
      final adm = s['admission_no']?.toString() ?? s['id']?.toString() ?? '-';
      final name = s['name']?.toString() ?? s['student_name']?.toString() ?? '-';
      final cls = s['class_name']?.toString() ?? className;
      final parent = s['parent_name']?.toString() ?? '-';
      final contact = s['contact']?.toString() ?? '-';
      final att = s['attendance_pct'] != null ? '${(s['attendance_pct'] as num).toStringAsFixed(1)}%' : 'N/A';
      final grade = s['cbse_grade']?.toString() ?? s['grade']?.toString() ?? 'N/A';

      dataSheet.appendRow([
        TextCellValue(roll),
        TextCellValue(adm),
        TextCellValue(name),
        TextCellValue(cls),
        TextCellValue(parent),
        TextCellValue(contact),
        TextCellValue(att),
        TextCellValue(grade),
      ]);
    }

    // Totals row
    dataSheet.appendRow([]);
    dataSheet.appendRow([
      TextCellValue('TOTAL'),
      IntCellValue(students.length),
      TextCellValue('STUDENTS'),
    ]);

    // Remove default Sheet1 if exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final cleanName = className.replaceAll(' ', '_').replaceAll('-', '_');
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Roster_${cleanName}_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R01: Exports 30-Day Attendance Trend as an official Excel (.xlsx) workbook
  static Future<void> exportAttendanceTrendExcel({
    required BuildContext context,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> trendRows,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - ATTENDANCE TREND AUDIT')]);
    summarySheet.appendRow([TextCellValue('Class Cohort:'), TextCellValue(className)]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Audit Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Statutory Rule:'), TextCellValue('CBSE Minimum 75.0% Attendance Requirement')]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Attendance Trend'];
    dataSheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Day'),
      TextCellValue('Present Students'),
      TextCellValue('Total Marked'),
      TextCellValue('Attendance Rate (%)'),
      TextCellValue('Statutory Compliance'),
    ]);

    double totalPct = 0;
    int markedDays = 0;

    for (final r in trendRows) {
      final date = r['date']?.toString() ?? '-';
      final day = r['day']?.toString() ?? '-';
      final present = (r['present'] as num?)?.toInt() ?? 0;
      final total = (r['total'] as num?)?.toInt() ?? 0;
      final pct = (r['percent'] as num?)?.toDouble() ?? 0.0;
      final isMarked = (r['is_marked'] as bool?) ?? (total > 0);

      if (isMarked) {
        totalPct += pct;
        markedDays++;
      }

      dataSheet.appendRow([
        TextCellValue(date),
        TextCellValue(day),
        IntCellValue(present),
        IntCellValue(total),
        TextCellValue(isMarked ? '${pct.toStringAsFixed(1)}%' : 'Not Recorded'),
        TextCellValue(!isMarked ? 'UNRECORDED' : (pct >= 75.0 ? 'MEETS STATUTORY RULE' : 'BELOW 75% TARGET')),
      ]);
    }

    final avgRate = markedDays > 0 ? totalPct / markedDays : 0.0;
    dataSheet.appendRow([]);
    dataSheet.appendRow([
      TextCellValue('30-DAY AVERAGE'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('${avgRate.toStringAsFixed(1)}%'),
      TextCellValue(avgRate >= 75.0 ? 'COMPLIANT' : 'DEFICIT ALERT'),
    ]);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final clean = className.replaceAll(' ', '_').replaceAll('-', '_');
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Attendance_Trend_${clean}_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R03: Exports Attendance Defaulters List (<75%) as an official Excel (.xlsx) workbook
  static Future<void> exportDefaultersExcel({
    required BuildContext context,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> defaulters,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - ATTENDANCE DEFAULTERS REGISTER')]);
    summarySheet.appendRow([TextCellValue('Class Cohort:'), TextCellValue(className)]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Generated Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Defaulter Criteria:'), TextCellValue('Attendance Rate Strictly < 75.0%')]);
    summarySheet.appendRow([TextCellValue('Total Defaulters:'), IntCellValue(defaulters.length)]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Defaulters List'];
    dataSheet.appendRow([
      TextCellValue('Roll Number'),
      TextCellValue('Admission No'),
      TextCellValue('Student Name'),
      TextCellValue('Class'),
      TextCellValue('Attendance %'),
      TextCellValue('Deficit Reason'),
      TextCellValue('Parent / Guardian'),
      TextCellValue('Contact Number'),
    ]);

    for (final s in defaulters) {
      final roll = s['roll_number']?.toString() ?? '-';
      final adm = s['admission_no']?.toString() ?? s['id']?.toString() ?? '-';
      final name = s['name']?.toString() ?? s['student_name']?.toString() ?? '-';
      final cls = s['class_name']?.toString() ?? className;
      final att = (s['attendance_pct'] as num?)?.toDouble() ?? 0.0;
      final reason = s['reason']?.toString() ?? 'Attendance below 75% statutory threshold';
      final parent = s['parent_name']?.toString() ?? '-';
      final contact = s['contact']?.toString() ?? '-';

      dataSheet.appendRow([
        TextCellValue(roll),
        TextCellValue(adm),
        TextCellValue(name),
        TextCellValue(cls),
        TextCellValue('${att.toStringAsFixed(1)}%'),
        TextCellValue(reason),
        TextCellValue(parent),
        TextCellValue(contact),
      ]);
    }

    dataSheet.appendRow([]);
    dataSheet.appendRow([
      TextCellValue('TOTAL DEFAULTERS'),
      IntCellValue(defaulters.length),
    ]);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final clean = className.replaceAll(' ', '_').replaceAll('-', '_');
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Defaulters_${clean}_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R04: Exports Class Performance / Gradebook as an official Excel (.xlsx) workbook
  static Future<void> exportGradebookExcel({
    required BuildContext context,
    required String className,
    required String examType,
    required String teacherName,
    required List<Map<String, dynamic>> students,
    double? classAverage,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - OFFICIAL CLASS GRADEBOOK')]);
    summarySheet.appendRow([TextCellValue('Class Cohort:'), TextCellValue(className)]);
    summarySheet.appendRow([TextCellValue('Examination Term:'), TextCellValue(examType)]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Date Generated:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Class Average:'), TextCellValue('${classAverage?.toStringAsFixed(1) ?? "0.0"}%')]);
    summarySheet.appendRow([TextCellValue('Total Students Evaluated:'), IntCellValue(students.length)]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Gradebook'];
    dataSheet.appendRow([
      TextCellValue('Rank'),
      TextCellValue('Roll Number'),
      TextCellValue('Student Name'),
      TextCellValue('Marks Obtained'),
      TextCellValue('Total Max Marks'),
      TextCellValue('Percentage (%)'),
      TextCellValue('CBSE Grade'),
      TextCellValue('Remarks / Narrative'),
      TextCellValue('Verdict'),
    ]);

    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final rank = s['rank']?.toString() ?? '${i + 1}';
      final roll = s['roll_number']?.toString() ?? '-';
      final name = s['name']?.toString() ?? s['student_name']?.toString() ?? s['student']?.toString() ?? '-';
      final obt = (s['marks_obtained'] as num?)?.toDouble() ?? (s['marks'] as num?)?.toDouble() ?? 0.0;
      final maxM = (s['total_marks'] as num?)?.toDouble() ?? (s['max'] as num?)?.toDouble() ?? 100.0;
      final pct = maxM > 0 ? (obt / maxM) * 100 : 0.0;
      final grade = s['grade']?.toString() ?? s['cbse_grade']?.toString() ?? 'D';
      final remark = s['remarks']?.toString() ?? s['cbse_remarks']?.toString() ?? '-';
      final isPassed = pct >= 33.0;

      dataSheet.appendRow([
        TextCellValue('#$rank'),
        TextCellValue(roll),
        TextCellValue(name),
        TextCellValue(obt.toStringAsFixed(1)),
        TextCellValue(maxM.toStringAsFixed(0)),
        TextCellValue('${pct.toStringAsFixed(1)}%'),
        TextCellValue(grade),
        TextCellValue(remark),
        TextCellValue(isPassed ? 'PASSED' : 'REMEDIAL SUPPORT'),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final cleanClass = className.replaceAll(' ', '_').replaceAll('-', '_');
      final cleanExam = examType.replaceAll(' ', '_').replaceAll('-', '_');
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Gradebook_${cleanClass}_${cleanExam}_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R05: Exports Subject-Wise Comparison Averages as an official Excel (.xlsx) workbook
  static Future<void> exportSubjectAveragesExcel({
    required BuildContext context,
    required String teacherName,
    required List<Map<String, dynamic>> subjectAverages,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - SUBJECT PERFORMANCE AVERAGES')]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Generated Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Total Subjects Compared:'), IntCellValue(subjectAverages.length)]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Subject Averages'];
    dataSheet.appendRow([
      TextCellValue('Subject Name'),
      TextCellValue('Evaluated Students Count'),
      TextCellValue('Class Average (%)'),
      TextCellValue('Highest Score (%)'),
      TextCellValue('Lowest Score (%)'),
      TextCellValue('Performance Band'),
    ]);

    for (final sa in subjectAverages) {
      final sub = sa['subject']?.toString() ?? 'Subject';
      final count = (sa['count'] as num?)?.toInt() ?? 0;
      final avg = (sa['average'] as num?)?.toDouble() ?? 0.0;
      final high = (sa['highest'] as num?)?.toDouble() ?? 0.0;
      final low = (sa['lowest'] as num?)?.toDouble() ?? 0.0;
      final band = avg >= 80 ? 'EXEMPLARY' : (avg >= 60 ? 'PROFICIENT' : 'NEEDS INTERVENTION');

      dataSheet.appendRow([
        TextCellValue(sub),
        IntCellValue(count),
        TextCellValue('${avg.toStringAsFixed(1)}%'),
        TextCellValue('${high.toStringAsFixed(1)}%'),
        TextCellValue('${low.toStringAsFixed(1)}%'),
        TextCellValue(band),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Subject_Averages_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R08: Exports Homework Submissions & Grading Register as an official Excel (.xlsx) workbook
  static Future<void> exportHomeworkSubmissionsExcel({
    required BuildContext context,
    required String homeworkTitle,
    required String subject,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> submissions,
    List<Map<String, dynamic>> allEnrolledStudents = const [],
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - HOMEWORK SUBMISSION AUDIT')]);
    summarySheet.appendRow([TextCellValue('Homework Task:'), TextCellValue(homeworkTitle)]);
    summarySheet.appendRow([TextCellValue('Subject:'), TextCellValue(subject)]);
    summarySheet.appendRow([TextCellValue('Class Cohort:'), TextCellValue(className)]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Audit Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Total Submissions Received:'), IntCellValue(submissions.length)]);
    summarySheet.appendRow([TextCellValue('Total Enrolled Students:'), IntCellValue(allEnrolledStudents.length)]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Submissions Register'];
    dataSheet.appendRow([
      TextCellValue('Roll Number'),
      TextCellValue('Student Name'),
      TextCellValue('Submission Status'),
      TextCellValue('Submitted Date/Time'),
      TextCellValue('Student Note'),
      TextCellValue('Teacher Feedback'),
      TextCellValue('Reviewed Date'),
    ]);

    final subMap = <String, Map<String, dynamic>>{};
    for (final s in submissions) {
      final key = (s['student_id'] ?? s['student_username'] ?? s['id'] ?? '').toString();
      if (key.isNotEmpty) subMap[key] = s;
    }

    final targetList = allEnrolledStudents.isNotEmpty ? allEnrolledStudents : submissions;

    for (final std in targetList) {
      final sId = (std['id'] ?? std['username'] ?? '').toString();
      final name = (std['name'] ?? std['student_name'] ?? 'Student').toString();
      final roll = (std['roll_number'] ?? std['roll_no'] ?? '-').toString();
      final sub = subMap[sId];

      final status = sub != null ? (sub['status']?.toString().toUpperCase() ?? 'SUBMITTED') : 'MISSING';
      final when = sub?['submitted_at']?.toString() ?? '-';
      final note = sub?['note']?.toString() ?? '-';
      final feedback = sub?['teacher_feedback']?.toString() ?? '-';
      final reviewed = sub?['reviewed_at']?.toString() ?? '-';

      dataSheet.appendRow([
        TextCellValue(roll),
        TextCellValue(name),
        TextCellValue(status),
        TextCellValue(when),
        TextCellValue(note),
        TextCellValue(feedback),
        TextCellValue(reviewed),
      ]);
    }

    dataSheet.appendRow([]);
    dataSheet.appendRow([
      TextCellValue('TOTAL ENROLLED'),
      IntCellValue(allEnrolledStudents.length),
      TextCellValue('SUBMITTED: ${submissions.length}'),
    ]);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final cleanTask = homeworkTitle.replaceAll(' ', '_').replaceAll('-', '_');
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Homework_${cleanTask}_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R09: Exports Lesson Plan Syllabus Velocity as an official Excel (.xlsx) workbook
  static Future<void> exportLessonPlanVelocityExcel({
    required BuildContext context,
    required String teacherName,
    required List<Map<String, dynamic>> velocityList,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - LESSON PLAN SYLLABUS VELOCITY')]);
    summarySheet.appendRow([TextCellValue('Faculty:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Audit Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Total Cohorts Tracked:'), IntCellValue(velocityList.length)]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Syllabus Pacing'];
    dataSheet.appendRow([
      TextCellValue('Class Cohort'),
      TextCellValue('Assigned Role'),
      TextCellValue('Total Planned Units'),
      TextCellValue('Completed / Taught'),
      TextCellValue('In Progress Units'),
      TextCellValue('Lagging / Review Topics'),
      TextCellValue('Curriculum Coverage (%)'),
      TextCellValue('Pacing Status'),
    ]);

    for (final v in velocityList) {
      final cName = v['class_name']?.toString() ?? 'Class';
      final role = v['role']?.toString() ?? 'Faculty';
      final total = (v['total_plans'] as num?)?.toInt() ?? 0;
      final taught = (v['taught_count'] as num?)?.toInt() ?? 0;
      final inProg = (v['in_progress'] as num?)?.toInt() ?? 0;
      final lagging = (v['lagging_count'] as num?)?.toInt() ?? 0;
      final rate = (v['completion_rate'] as num?)?.toDouble() ?? 0.0;
      final status = rate >= 70 ? 'ON SCHEDULE' : (lagging > 0 ? 'LAGGING ALERT' : 'IN PROGRESS');

      dataSheet.appendRow([
        TextCellValue(cName),
        TextCellValue(role),
        IntCellValue(total),
        IntCellValue(taught),
        IntCellValue(inProg),
        IntCellValue(lagging),
        TextCellValue('${rate.toStringAsFixed(1)}%'),
        TextCellValue(status),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Syllabus_Velocity_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }

  /// T-R12: Exports Weekly Teaching Workload as an official Excel (.xlsx) workbook
  static Future<void> exportWeeklyWorkloadExcel({
    required BuildContext context,
    required String teacherName,
    required Map<String, dynamic> workload,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('SHIVALIK INTERNATIONAL SCHOOL - WEEKLY FACULTY WORKLOAD')]);
    summarySheet.appendRow([TextCellValue('Faculty Name:'), TextCellValue(teacherName)]);
    summarySheet.appendRow([TextCellValue('Audit Date:'), TextCellValue(_currentDate())]);
    summarySheet.appendRow([TextCellValue('Total Weekly Lectures:'), IntCellValue((workload['total_lectures'] as num?)?.toInt() ?? 0)]);
    summarySheet.appendRow([TextCellValue('Weekly Periods Capacity:'), IntCellValue(48)]);
    summarySheet.appendRow([TextCellValue('Free Periods Total:'), IntCellValue((workload['free_periods_total'] as num?)?.toInt() ?? 0)]);
    summarySheet.appendRow([TextCellValue('Utilization Rate:'), TextCellValue('${((workload['utilization_rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%')]);
    summarySheet.appendRow([]);

    // Sheet 2: Data
    final dataSheet = excel['Day-Wise Load'];
    dataSheet.appendRow([
      TextCellValue('Day of Week'),
      TextCellValue('Scheduled Lectures'),
      TextCellValue('Free Periods (of 8)'),
      TextCellValue('Load Status'),
    ]);

    final days = (workload['days'] as List?) ?? [];
    for (final d in days) {
      final dayName = d['day']?.toString() ?? '-';
      final lecs = (d['lectures'] as num?)?.toInt() ?? 0;
      final free = (d['free_periods'] as num?)?.toInt() ?? 0;
      final isOver = (d['is_overloaded'] as bool?) ?? false;

      dataSheet.appendRow([
        TextCellValue(dayName),
        IntCellValue(lecs),
        IntCellValue(free),
        TextCellValue(isOver ? 'HEAVY LOAD (>7)' : 'BALANCED'),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Teacher_Weekly_Workload_$dateSlug.xlsx';
      await downloadExcel(context: context, filename: filename, bytes: bytes);
    }
  }
}
