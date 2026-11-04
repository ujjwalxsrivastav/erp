import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds the official CBSE-style Holistic Progress Card as an A4 PDF and
/// opens the system share sheet (Download / Save to Files / Print).
class ReportCardPdf {
  ReportCardPdf._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor _ink = PdfColor.fromInt(0xFF111827);
  static const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);

  static Future<void> share({
    required String studentName,
    required String studentUsername,
    required String className,
    required String rollNo,
    required String admissionNo,
    required String examType,
    required String academicYear,
    required List<Map<String, dynamic>> marks,
    required Map<String, dynamic> analytics,
    required double attendancePct,
    required List<Map<String, dynamic>> coScholastic,
    required String teacherRemark,
    required String promotionVerdict,
    required bool isPromoted,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Shivalik School · Academic Office',
                style: pw.TextStyle(fontSize: 7.5, color: _grey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7.5, color: _grey)),
          ],
        ),
        build: (ctx) => _reportContents(
          studentName: studentName,
          studentUsername: studentUsername,
          className: className,
          rollNo: rollNo,
          admissionNo: admissionNo,
          examType: examType,
          academicYear: academicYear,
          marks: marks,
          analytics: analytics,
          attendancePct: attendancePct,
          coScholastic: coScholastic,
          teacherRemark: teacherRemark,
          promotionVerdict: promotionVerdict,
          isPromoted: isPromoted,
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'report_card_${studentUsername}_${examType.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> shareClass({
    required List<Map<String, dynamic>> students,
    required String className,
    required String examType,
    required String academicYear,
  }) async {
    if (students.isEmpty) {
      throw ArgumentError('At least one student report card is required.');
    }

    final doc = pw.Document();
    for (final student in students) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Shivalik School · Academic Office',
                  style: pw.TextStyle(fontSize: 7.5, color: _grey)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 7.5, color: _grey)),
            ],
          ),
          build: (ctx) => _reportContents(
            studentName: (student['student_name'] ?? 'Student').toString(),
            studentUsername: (student['student_username'] ?? '').toString(),
            className: className,
            rollNo: (student['roll_no'] ?? '-').toString(),
            admissionNo: (student['admission_no'] ?? '-').toString(),
            examType: examType,
            academicYear: academicYear,
            marks: List<Map<String, dynamic>>.from(student['marks'] as List),
            analytics:
                Map<String, dynamic>.from(student['analytics'] as Map),
            attendancePct:
                (student['attendance_pct'] as num?)?.toDouble() ?? 0,
            coScholastic: List<Map<String, dynamic>>.from(
                student['co_scholastic'] as List),
            teacherRemark: (student['teacher_remark'] ?? '').toString(),
            promotionVerdict:
                (student['promotion_verdict'] ?? '').toString(),
            isPromoted: student['is_promoted'] as bool? ?? false,
          ),
        ),
      );
    }

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'report_cards_${className.replaceAll(' ', '_')}_${examType.replaceAll(' ', '_')}.pdf',
    );
  }

  static List<pw.Widget> _reportContents({
    required String studentName,
    required String studentUsername,
    required String className,
    required String rollNo,
    required String admissionNo,
    required String examType,
    required String academicYear,
    required List<Map<String, dynamic>> marks,
    required Map<String, dynamic> analytics,
    required double attendancePct,
    required List<Map<String, dynamic>> coScholastic,
    required String teacherRemark,
    required String promotionVerdict,
    required bool isPromoted,
  }) {
    return [
      _header(examType, academicYear),
      pw.SizedBox(height: 12),
      _studentBlock(
          studentName, rollNo, className, admissionNo, studentUsername),
      pw.SizedBox(height: 10),
      _summaryStrip(analytics, attendancePct),
      pw.SizedBox(height: 12),
      _sectionTitle('PART 1 · SCHOLASTIC SUBJECTS (CBSE 9-POINT SCALE)'),
      pw.SizedBox(height: 6),
      _marksTable(marks),
      pw.SizedBox(height: 12),
      _sectionTitle('PART 2 · CO-SCHOLASTIC & LIFE SKILLS (A / B / C)'),
      pw.SizedBox(height: 6),
      _coScholasticTable(coScholastic),
      pw.SizedBox(height: 12),
      _sectionTitle('PART 3 · RESULT ANALYTICS'),
      pw.SizedBox(height: 6),
      _analyticsBlock(analytics),
      pw.SizedBox(height: 12),
      _remarksBlock(teacherRemark, promotionVerdict, isPromoted),
      pw.SizedBox(height: 14),
      _signatures(),
    ];
  }

  static pw.Widget _header(String examType, String academicYear) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 42,
              height: 42,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: _teal,
                borderRadius: pw.BorderRadius.circular(9),
              ),
              child: pw.Text('S',
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SHIVALIK SCHOOL',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: _teal,
                          letterSpacing: 1.2)),
                  pw.Text(
                      'Affiliated to CBSE · Affiliation Code 3530128 · School Code 84021',
                      style: pw.TextStyle(fontSize: 7.5, color: _grey)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            color: _teal,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Text('HOLISTIC PROGRESS CARD',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2)),
              pw.Text('$examType Examination · Session $academicYear',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.white,
                      letterSpacing: 0.6)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _studentBlock(String name, String rollNo, String className,
      String admissionNo, String username) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: _kv('Student Name', name)),
          pw.Expanded(child: _kv('Roll No.', rollNo)),
          pw.Expanded(child: _kv('Class', className)),
          pw.Expanded(child: _kv('Admission No.', admissionNo)),
          pw.Expanded(child: _kv('Login ID', username)),
        ],
      ),
    );
  }

  static pw.Widget _summaryStrip(Map<String, dynamic> a, double attendance) {
    final pct = (a['percentage'] as num?)?.toDouble() ?? 0;
    return pw.Row(
      children: [
        _metricBox('TOTAL', '${a['obtained'] ?? 0} / ${a['max'] ?? 0}'),
        _metricBox('PERCENTAGE', '${pct.toStringAsFixed(1)}%'),
        _metricBox('GRADE', '${a['grade'] ?? '-'}'),
        _metricBox('ATTENDANCE', '${attendance.toStringAsFixed(1)}%'),
        _metricBox('SUBJECTS PASSED',
            '${a['subjects_passed'] ?? 0}/${a['subjects_total'] ?? 0}'),
      ],
    );
  }

  static pw.Widget _metricBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        padding: const pw.EdgeInsets.symmetric(vertical: 7),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF0FDFA),
          borderRadius: pw.BorderRadius.circular(5),
          border: pw.Border.all(color: PdfColor.fromInt(0xFF99F6E4)),
        ),
        child: pw.Column(
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _teal)),
            pw.SizedBox(height: 1),
            pw.Text(label,
                style: pw.TextStyle(fontSize: 6.5, color: _grey)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, color: _teal,
            letterSpacing: 0.8));
  }

  static pw.Widget _marksTable(List<Map<String, dynamic>> marks) {
    pw.Widget cell(String text,
        {bool header = false,
        bool alignRight = false,
        bool bold = false,
        PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(
          text,
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: header ? 8 : 8.5,
            fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? PdfColors.white : (color ?? _ink),
          ),
        ),
      );
    }

    int obt = 0, max = 0;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _teal),
        children: [
          cell('Subject', header: true),
          cell('Max', header: true, alignRight: true),
          cell('Obtained', header: true, alignRight: true),
          cell('%', header: true, alignRight: true),
          cell('Grade', header: true, alignRight: true),
        ],
      ),
    ];
    var i = 0;
    for (final m in marks) {
      final o = (m['marks_obtained'] ?? m['obtained'] ?? 0) as num;
      final t = (m['total_marks'] ?? m['total'] ?? 100) as num;
      obt += o.toInt();
      max += t.toInt();
      final p = t > 0 ? (o / t) * 100 : 0.0;
      final shade = i.isEven ? PdfColors.grey100 : PdfColors.white;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: shade),
        children: [
          cell(m['subject']?.toString() ?? ''),
          cell('${t.toInt()}', alignRight: true),
          cell('${o.toInt()}', alignRight: true, bold: true),
          cell(p.toStringAsFixed(1), alignRight: true),
          cell(m['grade']?.toString() ?? '-', alignRight: true, bold: true),
        ],
      ));
      i++;
    }
    final totalPct = max > 0 ? (obt / max) * 100 : 0.0;
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0FDFA)),
      children: [
        cell('GRAND TOTAL', bold: true),
        cell('$max', alignRight: true, bold: true),
        cell('$obt', alignRight: true, bold: true),
        cell(totalPct.toStringAsFixed(1), alignRight: true, bold: true),
        cell('-', alignRight: true, bold: true),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.1),
      },
      children: rows,
    );
  }

  static pw.Widget _coScholasticTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return pw.Text('Co-scholastic grades have not been published yet.',
          style: pw.TextStyle(fontSize: 8.5, color: _grey));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(0.8),
        2: pw.FlexColumnWidth(5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _teal),
          children: [
            _cell('Area', bold: true, white: true),
            _cell('Grade', bold: true, white: true),
            _cell('Descriptor', bold: true, white: true),
          ],
        ),
        ...rows.map((r) => pw.TableRow(
              children: [
                _cell(r['area']?.toString() ?? ''),
                _cell(r['grade']?.toString() ?? '-', bold: true),
                _cell(r['descriptor']?.toString() ?? ''),
              ],
            )),
      ],
    );
  }

  static pw.Widget _analyticsBlock(Map<String, dynamic> a) {
    final strongest = a['strongest'] as Map<String, dynamic>?;
    final weakest = a['weakest'] as Map<String, dynamic>?;
    final breakdown = (a['breakdown'] as List<dynamic>?) ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            _metricBox(
                'STRONGEST',
                strongest == null
                    ? '-'
                    : '${strongest['subject']} (${(strongest['percentage'] as num).toStringAsFixed(0)}%)'),
            _metricBox(
                'NEEDS FOCUS',
                weakest == null
                    ? '-'
                    : '${weakest['subject']} (${(weakest['percentage'] as num).toStringAsFixed(0)}%)'),
            _metricBox('GRADE POINT', '${a['grade_point'] ?? '-'}'),
          ],
        ),
        pw.SizedBox(height: 6),
        ...breakdown.map((row) {
          final m = row as Map<String, dynamic>;
          final pct = (m['percentage'] as num).toDouble().clamp(0, 100).toInt();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(
                    width: 90,
                    child: pw.Text(m['subject']?.toString() ?? '',
                        style: pw.TextStyle(fontSize: 8))),
                pw.Expanded(
                  child: pw.Container(
                    height: 7,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 380 * pct / 100,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              color: _teal,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(
                    width: 34,
                    child: pw.Text('$pct%',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _remarksBlock(
      String remark, String verdict, bool isPromoted) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('CLASS TEACHER REMARK',
              style: pw.TextStyle(
                  fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _grey)),
          pw.SizedBox(height: 3),
          pw.Text(remark.isEmpty ? '-' : remark,
              style: pw.TextStyle(fontSize: 8.5, color: _ink)),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: isPromoted
                  ? PdfColor.fromInt(0xFFECFDF5)
                  : PdfColor.fromInt(0xFFFEF2F2),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(verdict.isEmpty ? '-' : verdict,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: isPromoted
                        ? PdfColor.fromInt(0xFF047857)
                        : PdfColor.fromInt(0xFFB91C1C))),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(children: [
          pw.Text('______________________',
              style: pw.TextStyle(fontSize: 9, color: _grey)),
          pw.Text('Class Teacher',
              style: pw.TextStyle(fontSize: 7.5, color: _grey)),
        ]),
        pw.Column(children: [
          pw.Text('______________________',
              style: pw.TextStyle(fontSize: 9, color: _grey)),
          pw.Text("Parent's Signature",
              style: pw.TextStyle(fontSize: 7.5, color: _grey)),
        ]),
        pw.Column(children: [
          pw.Text('Dr. Meenakshi Srivastav',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.Text('Principal · Digital Seal',
              style: pw.TextStyle(fontSize: 7.5, color: _teal)),
        ]),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _teal)),
      ],
    );
  }

  static pw.Widget _cell(String text,
      {bool bold = false, bool white = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: white ? PdfColors.white : _ink)),
    );
  }
}
