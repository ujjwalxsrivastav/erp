import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../services/temp_admission_service.dart';

class OfferLetterScreen extends StatefulWidget {
  final String tempId;

  const OfferLetterScreen({super.key, required this.tempId});

  @override
  State<OfferLetterScreen> createState() => _OfferLetterScreenState();
}

class _OfferLetterScreenState extends State<OfferLetterScreen> {
  final _service = TempAdmissionService();
  Map<String, dynamic>? _offerData;
  bool _isLoading = true;
  bool _isProcessing = false;
  late Razorpay _razorpay;
  double _baseFee = 25000;
  double _hostelFee = 20000;
  double _transportFee = 10000;

  double get _totalFee {
    if (_offerData == null) return _baseFee;
    double total = _baseFee;
    if (_offerData!['hostel_required'] == true) total += _hostelFee;
    if (_offerData!['transportation_required'] == true) total += _transportFee;
    return total;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _initRazorpay();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.getOfferLetterData(widget.tempId);
    setState(() {
      _offerData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Admission Offer Letter'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_offerData != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadPdf,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offerData == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 16),
          const Text('Unable to load offer letter'),
          TextButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildOfferLetterCard(),
              const SizedBox(height: 20),
              _buildActionButtons(),
              const SizedBox(height: 100), // Space for floating buttons
            ],
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildOfferLetterCard() {
    final data = _offerData!;
    final today = DateTime.now();
    final formattedDate = '${today.day}/${today.month}/${today.year}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1e3a5f), Color(0xFF2d5a87)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Color(0xFF1e3a5f),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SHIVALIK COLLEGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dehradun, Uttarakhand',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Letter Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Ref
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Date: $formattedDate',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      'Ref: ${widget.tempId.toUpperCase()}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title
                const Center(
                  child: Text(
                    'PROVISIONAL ADMISSION OFFER LETTER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Greeting
                Text(
                  'Dear ${data['student_name'] ?? 'Student'},',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                // Body
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'We are pleased to inform you that you have been provisionally selected for admission to ',
                      ),
                      TextSpan(
                        text: '${data['course'] ?? 'the programme'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' at '),
                      const TextSpan(
                        text: 'Shivalik College',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' for the academic session '),
                      TextSpan(
                        text: '${data['session'] ?? '2025-26'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Student Details Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF1e3a5f).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Student Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3a5f),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Name', data['student_name'] ?? '-'),
                      _buildDetailRow('S/o / D/o', data['father_name'] ?? '-'),
                      _buildDetailRow('Programme', data['programme'] ?? '-'),
                      _buildDetailRow('Course', data['course'] ?? '-'),
                      _buildDetailRow('Session', data['session'] ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Terms
                const Text(
                  'Terms & Conditions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildTerm(
                    '1. This offer is valid for 7 days from the date of issue.'),
                _buildTerm(
                    '2. Admission is subject to verification of original documents.'),
                _buildTerm(
                    '3. An acceptance fee of ₹${_totalFee.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} must be paid to confirm admission.'),
                _buildTerm('4. This offer is non-transferable.'),
                const SizedBox(height: 20),

                // Fee Box - Professional Breakdown
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1e3a5f).withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.receipt_long,
                                color: Color(0xFF1e3a5f), size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Fee Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1e3a5f),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildFeeRow('Base Acceptance Fee', _baseFee),
                            if (_offerData!['hostel_required'] == true)
                              _buildFeeRow('Hostel Facility Fee', _hostelFee),
                            if (_offerData!['transportation_required'] == true)
                              _buildFeeRow('Transportation Fee', _transportFee),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Payable Amount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '₹${_totalFee.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Closing
                const Text(
                  'We welcome you to the Shivalik family and look forward to your bright academic future with us.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),

                // Signature
                const Text('Warm Regards,'),
                const SizedBox(height: 24),
                const Text(
                  'Dean of Admissions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Shivalik College',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            '₹${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTerm(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _showRejectDialog,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.close),
            label: const Text('Reject Offer',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _initiatePayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.green.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.payment),
            label: Text(
                'Accept & Pay ₹${_totalFee.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPdf() async {
    final data = _offerData!;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SHIVALIK COLLEGE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Dehradun, Uttarakhand'),
                    pw.Divider(thickness: 2),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Date & Ref
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  pw.Text('Ref: ${widget.tempId.toUpperCase()}'),
                ],
              ),
              pw.SizedBox(height: 24),

              // Title
              pw.Center(
                child: pw.Text(
                  'PROVISIONAL ADMISSION OFFER LETTER',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Body
              pw.Text('Dear ${data['student_name'] ?? 'Student'},'),
              pw.SizedBox(height: 12),
              pw.Text(
                'We are pleased to inform you that you have been provisionally selected for admission to ${data['course'] ?? 'the programme'} at Shivalik College for the academic session ${data['session'] ?? '2025-26'}.',
                style: const pw.TextStyle(lineSpacing: 1.5),
              ),
              pw.SizedBox(height: 16),

              // Details Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Student Details:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Name: ${data['student_name'] ?? '-'}'),
                    pw.Text('S/o / D/o: ${data['father_name'] ?? '-'}'),
                    pw.Text('Programme: ${data['programme'] ?? '-'}'),
                    pw.Text('Course: ${data['course'] ?? '-'}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Terms
              pw.Text('Terms & Conditions:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                  '1. This offer is valid for 7 days from the date of issue.'),
              pw.Text(
                  '2. Admission is subject to verification of original documents.'),
              pw.Text(
                  '3. An acceptance fee of Rs. ${_totalFee.toInt()} must be paid to confirm admission.'),
              pw.SizedBox(height: 20),

              // Closing
              pw.Text('Warm Regards,'),
              pw.SizedBox(height: 40),
              pw.Text('Dean of Admissions',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Shivalik College'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void _initiatePayment() {
    final data = _offerData!;
    var options = {
      'key': dotenv.get('RAZORPAY_KEY', fallback: 'rzp_test_Rj8ZriIK5tkUjG'),
      'amount': (_totalFee * 100).toInt(), // Dynamic amount in paise
      'currency': 'INR',
      'name': 'Shivalik College',
      'description': 'Admission Acceptance Fee',
      'prefill': {
        'contact': data['phone'] ?? '',
        'email': data['email'] ?? '',
      },
      'theme': {'color': '#1e3a5f'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      _showSnackBar('Error initiating payment', isError: true);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);

    final result = await _service.acceptOffer(
      tempId: widget.tempId,
      paymentId: response.paymentId ?? 'unknown',
      paymentAmount: _totalFee,
    );

    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      if (mounted) {
        _showSuccessDialog(result['permanentId'] ?? 'Unknown');
      }
    } else {
      _showSnackBar(result['message'] ?? 'Error processing admission',
          isError: true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showSnackBar('Payment failed: ${response.message ?? 'Unknown error'}',
        isError: true);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnackBar('External wallet selected: ${response.walletName}');
  }

  void _showSuccessDialog(String permanentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            const Text(
              '🎉 Congratulations!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your admission has been confirmed!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Your Permanent Student ID'),
                  const SizedBox(height: 8),
                  Text(
                    permanentId,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Username & Password: Same as ID',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  this.context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Login with New ID',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reject Offer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to reject this admission offer? This action cannot be undone.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isProcessing = true);

              final success = await _service.rejectOffer(
                widget.tempId,
                reason: reasonController.text.isEmpty
                    ? 'Student rejected the offer'
                    : reasonController.text,
              );

              setState(() => _isProcessing = false);

              if (success) {
                if (mounted) {
                  _showRejectionConfirmation();
                }
              } else {
                _showSnackBar('Error rejecting offer', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectionConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 64),
            SizedBox(height: 16),
            Text(
              'Offer Rejected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your admission offer has been rejected. Your temporary account has been deactivated.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  this.context.go('/login');
                }
              },
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
