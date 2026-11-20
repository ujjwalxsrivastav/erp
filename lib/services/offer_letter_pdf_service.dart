import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Service for generating admission offer letter PDFs with signatures.
///
/// Uses a bundled Noto Sans font so Unicode characters such as the Indian
/// Rupee sign (₹) and bullets render correctly — the PDF core fonts do not
/// contain those glyphs.
class OfferLetterPdfService {
  OfferLetterPdfService._();
  static final OfferLetterPdfService instance = OfferLetterPdfService._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static const PdfColor _navy = PdfColor.fromInt(0xFF0B2A5B);
  static const PdfColor _navySoft = PdfColor.fromInt(0xFF1E3A6E);
  static const PdfColor _gold = PdfColor.fromInt(0xFFB4862B);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5B6675);
  static const PdfColor _line = PdfColor.fromInt(0xFFD5DBE3);
  static const PdfColor _softBlue = PdfColor.fromInt(0xFFF3F6FB);
  static const PdfColor _amberBg = PdfColor.fromInt(0xFFFFF8E7);
  static const PdfColor _amberLine = PdfColor.fromInt(0xFFE8C77A);
  static const PdfColor _amberInk = PdfColor.fromInt(0xFF7A5410);

  Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    _regular = pw.Font.ttf(regularData);
    _bold = pw.Font.ttf(boldData);
  }

  /// Generates the offer letter PDF bytes as a single, formal A4 page.
  Future<Uint8List> generateOfferLetter({
    required Map<String, dynamic> admission,
    required String schoolName,
    required String schoolAddress,
    required String affiliationNo,
    required String principalName,
    String? principalSignaturePath,
    String? schoolStampPath,
  }) async {
    await _ensureFonts();
    final theme = pw.ThemeData.withFont(base: _regular, bold: _bold);
    final pdf = pw.Document();

    // Load signature/stamp images if provided
    pw.MemoryImage? principalSig;
    pw.MemoryImage? schoolStamp;

    if (principalSignaturePath != null) {
      try {
        final bytes = await rootBundle.load(principalSignaturePath);
        principalSig = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }
    if (schoolStampPath != null) {
      try {
        final bytes = await rootBundle.load(schoolStampPath);
        schoolStamp = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    final appNo = admission['application_no']?.toString() ??
        admission['id']?.toString() ??
        '';
    final studentName = admission['applicant_name']?.toString() ?? 'Student';
    final parentName = admission['parent_name']?.toString() ?? 'Parent';
    final grade = admission['grade_applying']?.toString() ?? 'Class 1';
    final stream = admission['stream']?.toString() ?? '';
    final feeDemanded =
        (admission['fee_demanded'] as num?)?.toDouble() ?? 35000.0;
    final offerValidTill = admission['offer_valid_till']?.toString() ?? '';
    final offerDate = admission['offer_date']?.toString() ?? '';
    final session = _academicSessionFromDate(
        offerDate.isNotEmpty ? offerDate : DateTime.now().toIso8601String());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 32, 38, 28),
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(
              schoolName: schoolName,
              schoolAddress: schoolAddress,
              affiliationNo: affiliationNo,
            ),
            pw.SizedBox(height: 14),

            // Document title
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'OFFER OF PROVISIONAL ADMISSION',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      letterSpacing: 1.6,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Academic Session $session',
                    style: pw.TextStyle(fontSize: 9.5, color: _muted),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(width: 60, height: 1.4, color: _gold),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Reference and date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ref. No.: $appNo',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _muted),
                ),
                pw.Text(
                  'Date: ${_formatDate(offerDate.isNotEmpty ? offerDate : DateTime.now().toIso8601String())}',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _muted),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Salutation
            pw.Text(
              'Dear $parentName,',
              style: pw.TextStyle(fontSize: 10, color: _ink),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Subject: Provisional Offer of Admission — $grade, Session $session',
              style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _navySoft),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'We are pleased to inform you that, following the document scrutiny and academic '
              'assessment, your ward $studentName has been provisionally granted admission to '
              '$grade at $schoolName for the Academic Session $session. This offer is subject to '
              'the terms set out below.',
              style: pw.TextStyle(fontSize: 9.5, color: _ink, lineSpacing: 2.4),
            ),
            pw.SizedBox(height: 9),

            // Applicant details
            _buildDetailsTable(
              studentName: studentName,
              parentName: parentName,
              grade: stream.isNotEmpty ? '$grade ($stream)' : grade,
              session: session,
              appNo: appNo,
            ),
            pw.SizedBox(height: 9),

            // Fee structure
            pw.Text(
              'Fee Structure (Provisional)',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy),
            ),
            pw.SizedBox(height: 4),
            _buildFeeTable(feeDemanded),
            pw.SizedBox(height: 8),

            // Validity
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: pw.BoxDecoration(
                color: _amberBg,
                border: pw.Border.all(color: _amberLine, width: 0.7),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 13,
                    height: 13,
                    margin: const pw.EdgeInsets.only(top: 0.5, right: 7),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _amberInk, width: 0.8),
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '!',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _amberInk,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'This offer is valid until ${_formatDate(offerValidTill)}. Please complete the '
                      'enrolment formalities and fee payment on or before this date to confirm the seat.',
                      style: pw.TextStyle(
                          fontSize: 8.8, color: _amberInk, lineSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 9),

            // Terms and conditions
            _buildTermsSection(),
            pw.SizedBox(height: 12),

            // Signature block
            _buildSignatureBlock(
              schoolName: schoolName,
              principalName: principalName,
              principalSignature: principalSig,
              schoolStamp: schoolStamp,
              parentName: parentName,
              studentName: studentName,
            ),

            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: _line, width: 0.5)),
              ),
              child: pw.Text(
                'This is a computer-generated offer letter issued provisionally and is valid only '
                'when accompanied by the school seal and authorised signature.',
                style: pw.TextStyle(fontSize: 7.2, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader({
    required String schoolName,
    required String schoolAddress,
    required String affiliationNo,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 48,
              height: 48,
              decoration: pw.BoxDecoration(
                color: _navy,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(
                child: pw.Text(
                  _initials(schoolName),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    schoolName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    schoolAddress,
                    style: pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Affiliated to CBSE, New Delhi  •  Affiliation No: $affiliationNo',
                    style: pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2, color: _navy),
        pw.SizedBox(height: 1.5),
        pw.Container(height: 0.6, color: _gold),
      ],
    );
  }

  pw.Widget _buildDetailsTable({
    required String studentName,
    required String parentName,
    required String grade,
    required String session,
    required String appNo,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.15),
        1: pw.FlexColumnWidth(1.85),
        2: pw.FlexColumnWidth(1.15),
        3: pw.FlexColumnWidth(1.85),
      },
      children: [
        _detailsRow('Student Name', studentName, 'Application No.', appNo),
        _detailsRow('Parent / Guardian', parentName, 'Class Applied', grade),
        _detailsRow('Academic Session', session, 'Offer Status', 'Provisional'),
      ],
    );
  }

  pw.TableRow _detailsRow(
      String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        _cell(label1, bold: true, background: _softBlue),
        _cell(value1),
        _cell(label2, bold: true, background: _softBlue),
        _cell(value2),
      ],
    );
  }

  pw.Widget _cell(String text,
      {bool bold = false, PdfColor? background}) {
    return pw.Container(
      color: background,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? _navySoft : _ink,
        ),
      ),
    );
  }

  pw.Widget _buildFeeTable(double feeDemanded) {
    const admissionFee = 10000.0;
    const cautionMoney = 5000.0;
    final firstQuarter = feeDemanded - admissionFee - cautionMoney;

    pw.TableRow row(String label, double amount,
        {bool total = false, bool bold = false}) {
      return pw.TableRow(
        decoration: total
            ? const pw.BoxDecoration(color: _softBlue)
            : null,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: total ? _navy : _ink,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: pw.Text(
              _rupees(amount),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: total ? _navy : _ink,
              ),
            ),
          ),
        ],
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navy),
          children: [
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: pw.Text(
                'Particulars',
                style: pw.TextStyle(
                    fontSize: 8.8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
              ),
            ),
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: pw.Text(
                'Amount',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 8.8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
              ),
            ),
          ],
        ),
        row('Admission Fee (One-Time)', admissionFee),
        row('Caution Money (Refundable)', cautionMoney),
        row('First Quarter Fee', firstQuarter),
        row('Total Payable', feeDemanded, total: true, bold: true),
      ],
    );
  }

  pw.Widget _buildTermsSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Terms & Conditions',
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _navy),
        ),
        pw.SizedBox(height: 4),
        ..._numberedTerms().asMap().entries.map((entry) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 14,
                  child: pw.Text(
                    '${entry.key + 1}.',
                    style: pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    entry.value,
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _ink, lineSpacing: 1.8),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<String> _numberedTerms() => const [
        'This admission is provisional and subject to verification of all original documents at the time of physical enrolment.',
        'The fee structure is subject to revision as per school policy and CBSE guidelines.',
        'Caution money is refundable only upon withdrawal or transfer, with due clearance certificates.',
        'Attendance of 75% is mandatory as per CBSE norms; failure may affect promotion and examination eligibility.',
        'The school reserves the right to cancel admission if any information provided is found to be incorrect.',
      ];

  pw.Widget _buildSignatureBlock({
    required String schoolName,
    required String principalName,
    pw.MemoryImage? principalSignature,
    pw.MemoryImage? schoolStamp,
    required String parentName,
    required String studentName,
  }) {
    pw.Widget signatureArea({String? label}) {
      return pw.Container(
        height: 42,
        alignment: pw.Alignment.center,
        child: label == null
            ? pw.SizedBox()
            : pw.Text(
                label,
                style: pw.TextStyle(fontSize: 8, color: _muted),
              ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 0.6, color: _line),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Principal / school side
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (principalSignature != null)
                    pw.Container(
                      height: 34,
                      child: pw.Image(principalSignature, fit: pw.BoxFit.contain),
                    )
                  else
                    signatureArea(label: '(Principal\u2019s Signature)'),
                  if (schoolStamp != null)
                    pw.Container(
                      height: 26,
                      child: pw.Image(schoolStamp, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.SizedBox(height: 8),
                  pw.Container(height: 0.6, color: _line, width: 120),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    principalName,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy),
                  ),
                  pw.Text(
                    'Principal',
                    style: pw.TextStyle(fontSize: 8, color: mildGrey),
                  ),
                  pw.Text(
                    schoolName,
                    style: pw.TextStyle(fontSize: 7.5, color: _muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            // Parent / student acceptance side
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Parent / Guardian Acceptance',
                    style: pw.TextStyle(
                        fontSize: 8.8,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'I accept the offer of admission on behalf of my ward $studentName and '
                    'agree to abide by the rules and regulations of $schoolName.',
                    style: pw.TextStyle(
                        fontSize: 8, color: _ink, lineSpacing: 1.6),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                                width: 110, height: 0.6, color: _line),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              parentName,
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _ink),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                                width: 80, height: 0.6, color: _line),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Date',
                              style: pw.TextStyle(
                                  fontSize: 8.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const PdfColor mildGrey = PdfColor.fromInt(0xFF6B7280);

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'SIS';
    if (words.length == 1) {
      final w = words.first;
      return w.length >= 3 ? w.substring(0, 3).toUpperCase() : w.toUpperCase();
    }
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }

  /// Formats an amount with the Indian Rupee sign and Indian digit grouping.
  String _rupees(double amount) {
    final value = amount.round().toString();
    if (value.length <= 3) return '₹$value';
    final last3 = value.substring(value.length - 3);
    var rest = value.substring(0, value.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '₹${groups.join(',')},$last3';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _academicSessionFromDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final year = dt.month >= 4 ? dt.year : dt.year - 1;
      return '$year-${(year + 1).toString().substring(2)}';
    } catch (_) {
      return '2026-27';
    }
  }

  /// Generates and shares the PDF (opens system share sheet / print dialog).
  Future<void> shareOfferLetterPdf({
    required Map<String, dynamic> admission,
    required String schoolName,
    required String schoolAddress,
    required String affiliationNo,
    required String principalName,
    String? principalSignaturePath,
    String? schoolStampPath,
    String? fileName,
  }) async {
    final bytes = await generateOfferLetter(
      admission: admission,
      schoolName: schoolName,
      schoolAddress: schoolAddress,
      affiliationNo: affiliationNo,
      principalName: principalName,
      principalSignaturePath: principalSignaturePath,
      schoolStampPath: schoolStampPath,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName ??
          'Offer_Letter_${admission['application_no'] ?? admission['id']}.pdf',
    );
  }

  /// Generates and opens the PDF for printing.
  Future<void> printOfferLetterPdf({
    required Map<String, dynamic> admission,
    required String schoolName,
    required String schoolAddress,
    required String affiliationNo,
    required String principalName,
    String? principalSignaturePath,
    String? schoolStampPath,
  }) async {
    final bytes = await generateOfferLetter(
      admission: admission,
      schoolName: schoolName,
      schoolAddress: schoolAddress,
      affiliationNo: affiliationNo,
      principalName: principalName,
      principalSignaturePath: principalSignaturePath,
      schoolStampPath: schoolStampPath,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
