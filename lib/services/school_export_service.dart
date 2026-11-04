import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';

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

  /// Shows a clean, modern export chooser modal with options for PDF and CSV
  static void showExportOptionsModal({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Future<void> Function() onExportPdf,
    required Future<void> Function() onExportCsv,
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
}
