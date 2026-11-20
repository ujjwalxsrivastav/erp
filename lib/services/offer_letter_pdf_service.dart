import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Service for generating admission offer letter PDFs with signatures.
class OfferLetterPdfService {
  OfferLetterPdfService._();
  static final OfferLetterPdfService instance = OfferLetterPdfService._();

  /// Generates the offer letter PDF bytes.
  Future<Uint8List> generateOfferLetter({
    required Map<String, dynamic> admission,
    required String schoolName,
    required String schoolAddress,
    required String affiliationNo,
    required String principalName,
    String? principalSignaturePath,
    String? schoolStampPath,
  }) async {
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

    final appNo = admission['application_no']?.toString() ?? admission['id']?.toString() ?? '';
    final studentName = admission['applicant_name']?.toString() ?? 'Student';
    final parentName = admission['parent_name']?.toString() ?? 'Parent';
    final grade = admission['grade_applying']?.toString() ?? 'Class 1';
    final feeDemanded = (admission['fee_demanded'] as num?)?.toDouble() ?? 35000.0;
    final offerValidTill = admission['offer_valid_till']?.toString() ?? '';
    final offerDate = admission['offer_date']?.toString() ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          // Header
          _buildHeader(
            schoolName: schoolName,
            schoolAddress: schoolAddress,
            affiliationNo: affiliationNo,
            appNo: appNo,
          ),
          pw.SizedBox(height: 24),

          // Title
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'PROVISIONAL ADMISSION OFFER LETTER',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // Reference and date
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Ref: $appNo',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
              ),
              pw.Text(
                'Date: ${_formatDate(offerDate.isNotEmpty ? offerDate : DateTime.now().toIso8601String())}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Salutation
          pw.Text(
            'Dear $parentName,',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 12),

          // Body
          pw.Text(
            'We are pleased to inform you that following the document scrutiny and academic assessment, '
            'your ward $studentName has been provisionally granted admission to $grade '
            'at $schoolName for the Academic Session ${_academicSessionFromDate(offerDate)}.',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800, lineSpacing: 1.4),
          ),
          pw.SizedBox(height: 16),

          // Fee structure table
          pw.Text(
            'Fee Structure (Provisional):',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 8),
          _buildFeeTable(feeDemanded),
          pw.SizedBox(height: 16),

          // Validity
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.amber200),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Icon(pw.IconData(0xe88f), color: PdfColors.amber700, size: 18),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    'This offer is valid until ${_formatDate(offerValidTill)}. '
                    'Please complete the enrolment formalities and fee payment before this date to confirm the seat.',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.amber900, lineSpacing: 1.3),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Terms and conditions
          _buildTermsSection(),
          pw.SizedBox(height: 30),

          // Signature block
          _buildSignatureBlock(
            principalName: principalName,
            principalSignature: principalSig,
            schoolStamp: schoolStamp,
            studentName: studentName,
            parentName: parentName,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader({
    required String schoolName,
    required String schoolAddress,
    required String affiliationNo,
    required String appNo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                color: PdfColors.blue900,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Center(
                child: pw.Text(
                  'SIS',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    schoolName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    schoolAddress,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Affiliated to CBSE, New Delhi • Affiliation No: $affiliationNo',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontWeight: pw.FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          height: 2,
          color: PdfColors.blue200,
        ),
      ],
    );
  }

  pw.Widget _buildFeeTable(double feeDemanded) {
    final admissionFee = 10000.0;
    final cautionMoney = 5000.0;
    final firstQuarter = feeDemanded - admissionFee - cautionMoney;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        _feeRow('Admission Fee (One-Time)', '₹${admissionFee.toStringAsFixed(0)}', isHeader: false),
        _feeRow('Caution Money (Refundable)', '₹${cautionMoney.toStringAsFixed(0)}', isHeader: false),
        _feeRow('First Quarter Fee', '₹${firstQuarter.toStringAsFixed(0)}', isHeader: false),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Total Payable', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('₹${feeDemanded.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  pw.TableRow _feeRow(String label, String amount, {bool isHeader = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(amount, style: pw.TextStyle(fontSize: 11, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    );
  }

  pw.Widget _buildTermsSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Terms & Conditions:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 8),
        ...[
          'This admission is provisional and subject to verification of all original documents at the time of physical enrolment.',
          'The fee structure is subject to revision as per school policy and CBSE guidelines.',
          'Caution money is refundable only upon withdrawal/transfer with due clearance certificates.',
          'Attendance of 75% is mandatory as per CBSE norms; failure may affect promotion/examination eligibility.',
          'The school reserves the right to cancel admission if any information provided is found to be incorrect.',
        ].map((t) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4, left: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  pw.Expanded(child: pw.Text(t, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
                ],
              ),
            )),
      ],
    );
  }

  pw.Widget _buildSignatureBlock({
    required String principalName,
    pw.MemoryImage? principalSignature,
    pw.MemoryImage? schoolStamp,
    required String studentName,
    required String parentName,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 16),
        pw.Text(
          'Authorised Signatures',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Principal signature with stamp
            pw.Expanded(
              child: pw.Column(
                children: [
                  if (principalSignature != null) ...[
                    pw.Container(
                      height: 60,
                      child: pw.Image(principalSignature, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 4),
                  ] else ...[
                    pw.Container(
                      height: 60,
                      child: pw.Center(
                        child: pw.Text(
                          '(Principal\'s Signature)',
                          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  if (schoolStamp != null) ...[
                    pw.Container(
                      height: 40,
                      child: pw.Image(schoolStamp, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 4),
                  ] else ...[
                    pw.Container(
                      height: 40,
                      child: pw.Center(
                        child: pw.Text(
                          '(School Stamp)',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Text(
                    principalName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Principal',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Shivalik International School',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            // Parent signature
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 60,
                    child: pw.Center(
                      child: pw.Text(
                        '(Parent\'s Signature)',
                        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    parentName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Parent / Guardian',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Date: _______________',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            // Student signature
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 60,
                    child: pw.Center(
                      child: pw.Text(
                        '(Student\'s Signature)',
                        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    studentName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Student',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Date: _______________',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
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
      filename: fileName ?? 'Offer_Letter_${admission['application_no'] ?? admission['id']}.pdf',
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