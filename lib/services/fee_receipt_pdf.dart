import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates a branded school fee receipt / statement as a PDF and opens the
/// system share sheet (Download / WhatsApp / Print / Save to Files).
///
/// The document carries a large light-grey "SHIVALIK SCHOOL" watermark behind
/// every page's content so a screenshot or printout is visibly authentic.
class FeeReceiptPdf {
  FeeReceiptPdf._();

  // NOTE: the default PDF font (Helvetica) has no ₹ glyph, so amounts are
  // rendered as "Rs. 24,500".
  static String _rs(double v) => 'Rs. ${v.toStringAsFixed(0)}';

  static String _num(dynamic v) => ((v as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);

  /// [ledger]  — every fee demand row (head, due_date, amount, paid_amount,
  ///             status) for the student.
  /// [receiptNo]/[paymentMode]/... — optional payment block; pass null to
  ///             download a plain fee statement instead of a payment receipt.
  static Future<void> share({
    required String studentName,
    required String className,
    required String admissionNo,
    required String studentUsername,
    required List<Map<String, dynamic>> ledger,
    String? receiptNo,
    String? paymentMode,
    double? paymentAmount,
    String? paymentDate,
    String title = 'FEE RECEIPT',
  }) async {
    double total = 0, paid = 0;
    for (final f in ledger) {
      final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
      final p = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
      total += amount;
      paid += (p < amount ? p : amount);
    }
    final outstanding = (total - paid).clamp(0.0, double.infinity);

    final doc = pw.Document();
    final now = DateTime.now();
    final generated =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    const teal = PdfColor.fromInt(0xFF0F766E);
    const ink = PdfColor.fromInt(0xFF111827);
    const grey = PdfColor.fromInt(0xFF6B7280);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Stack(
            children: [
              // ── Watermark (behind everything) ──
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.07,
                    child: pw.Transform.rotate(
                      angle: -0.45,
                      child: pw.Text(
                        'SHIVALIK SCHOOL',
                        style: pw.TextStyle(
                          fontSize: 52,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Content ──
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 46,
                        height: 46,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: teal,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(
                          'S',
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'SHIVALIK SCHOOL',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: teal,
                                letterSpacing: 1.2,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Knowledge · Character · Excellence   |   Academic Year 2026-27',
                              style: pw.TextStyle(fontSize: 8.5, color: grey),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: teal, width: 1),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'OFFICIAL RECEIPT',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(color: teal, thickness: 1.4, height: 18),

                  // Title
                  pw.Center(
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      receiptNo == null
                          ? 'Student Fee Statement'
                          : 'Receipt No. $receiptNo',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        color: receiptNo == null ? grey : teal,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Student block
                  _infoBox([
                    ['Student Name', studentName],
                    ['Class', className],
                    ['Admission No.', admissionNo],
                    ['Username', studentUsername],
                  ], teal, ink, grey),

                  // Payment block (payment receipts only)
                  if (receiptNo != null) ...[
                    pw.SizedBox(height: 10),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFECFDF5),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(
                            color: PdfColor.fromInt(0xFF10B981), width: 0.8),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: _kv('Amount Paid',
                                _rs(paymentAmount ?? 0), ink, teal),
                          ),
                          pw.Expanded(
                            child: _kv('Payment Mode', paymentMode ?? '-',
                                ink, teal),
                          ),
                          pw.Expanded(
                            child: _kv('Payment Date', paymentDate ?? '-',
                                ink, teal),
                          ),
                        ],
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 16),

                  // Ledger table
                  pw.Text(
                    'FEE DEMAND LEDGER',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: teal,
                        letterSpacing: 0.8),
                  ),
                  pw.SizedBox(height: 6),
                  _tableHeader(teal),
                  ...ledger.map((f) {
                    final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
                    final p = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
                    final settled = (p >= amount - 0.01);
                    final status =
                        (f['status']?.toString() ?? 'pending').toUpperCase();
                    return _tableRow(
                      head: f['head']?.toString() ?? 'Fee',
                      due: (f['due_date']?.toString() ?? '-').substring(
                          0,
                          (f['due_date']?.toString() ?? '').length >= 10
                              ? 10
                              : (f['due_date']?.toString() ?? '').length),
                      amount: _num(amount),
                      paid: _num(p < amount ? p : amount),
                      status: status,
                      settled: settled,
                      teal: teal,
                      grey: grey,
                      ink: ink,
                    );
                  }),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.6),

                  // Totals
                  _totalRow('Total Demanded', _rs(total), ink, false),
                  _totalRow('Total Paid', _rs(paid), teal, false),
                  _totalRow(
                    outstanding > 0 ? 'Outstanding' : 'Balance',
                    _rs(outstanding),
                    outstanding > 0
                        ? PdfColor.fromInt(0xFFEF4444)
                        : PdfColor.fromInt(0xFF10B981),
                    true,
                  ),

                  pw.SizedBox(height: 18),
                  pw.Container(
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
                        pw.Text(
                          outstanding > 0
                              ? 'Status: OUTSTANDING — please clear the balance at the earliest.'
                              : 'Status: NO DUES — all fee demands are fully settled.',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: outstanding > 0
                                ? PdfColor.fromInt(0xFFB45309)
                                : PdfColor.fromInt(0xFF047857),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'This is a computer-generated receipt and does not require a '
                          'physical signature. Verify using the receipt number above. '
                          'Generated on $generated.',
                          style: pw.TextStyle(fontSize: 7.5, color: grey),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Accounts Office',
                          style: pw.TextStyle(fontSize: 8.5, color: grey)),
                      pw.Text('Shivalik School · Fees & Accounts',
                          style: pw.TextStyle(fontSize: 8.5, color: grey)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: receiptNo == null
          ? 'shivalik_fee_statement_${studentUsername}.pdf'
          : 'shivalik_fee_receipt_$receiptNo.pdf',
    );
  }

  static pw.Widget _kv(String label, String value, PdfColor ink, PdfColor accent) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: accent)),
      ],
    );
  }

  static pw.Widget _infoBox(
      List<List<String>> pairs, PdfColor teal, PdfColor ink, PdfColor grey) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: _kv(pairs[0][0], pairs[0][1], ink, teal)),
          pw.Expanded(child: _kv(pairs[1][0], pairs[1][1], ink, teal)),
          pw.Expanded(child: _kv(pairs[2][0], pairs[2][1], ink, teal)),
          pw.Expanded(child: _kv(pairs[3][0], pairs[3][1], ink, teal)),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(PdfColor teal) {
    pw.Widget cell(String text, double flex, {bool right = false}) {
      return pw.Expanded(
        flex: (flex * 10).round(),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(color: teal),
      child: pw.Row(
        children: [
          cell('Fee Head', 3.2),
          cell('Due Date', 1.4),
          cell('Amount', 1.2, right: true),
          cell('Paid', 1.2, right: true),
          cell('Status', 1.2, right: true),
        ],
      ),
    );
  }

  static pw.Widget _tableRow({
    required String head,
    required String due,
    required String amount,
    required String paid,
    required String status,
    required bool settled,
    required PdfColor teal,
    required PdfColor grey,
    required PdfColor ink,
  }) {
    final statusColor =
        settled ? PdfColor.fromInt(0xFF10B981) : PdfColor.fromInt(0xFFEF4444);

    pw.Widget cell(String text, double flex,
        {bool right = false, PdfColor? color, bool bold = false}) {
      return pw.Expanded(
        flex: (flex * 10).round(),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 8.5,
            color: color ?? ink,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        ),
      ),
      child: pw.Row(
        children: [
          cell(head, 3.2),
          cell(due, 1.4, color: grey),
          cell('Rs. $amount', 1.2, right: true),
          cell('Rs. $paid', 1.2, right: true, color: teal),
          cell(status, 1.2, right: true, color: statusColor, bold: true),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, PdfColor color,
      bool strong) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: strong ? 11 : 9.5,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColors.grey700,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: strong ? 13 : 10,
                fontWeight: pw.FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }
}
