import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StaffPdfService {
  static Future<void> generateEmployeePdf(Map<String, dynamic> staff) async {
    final pdf = pw.Document();

    // Add pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(staff),
          pw.SizedBox(height: 20),
          _buildPersonalSection(staff),
          pw.SizedBox(height: 20),
          _buildProfessionalSection(staff),
          pw.SizedBox(height: 20),
          _buildSalarySection(staff),
          pw.SizedBox(height: 20),
          _buildDocumentsSection(staff),
          pw.SizedBox(height: 20),
          _buildExperienceSection(staff),
          pw.SizedBox(height: 20),
          _buildActivitySection(staff),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    // Save and open PDF
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Employee_${staff['id']}_${staff['name']}.pdf',
    );
  }

  static pw.Widget _buildHeader(Map<String, dynamic> staff) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#059669'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EMPLOYEE PROFILE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Shivalik College of Engineering',
                    style: pw.TextStyle(
                      color: PdfColors.white.shade(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColors.white,
                ),
                child: pw.Center(
                  child: pw.Text(
                    staff['name'].toString().substring(0, 1).toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 36,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#059669'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.white.shade(0.3)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    staff['name'],
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${staff['role']} • ${staff['department']}',
                    style: pw.TextStyle(
                      color: PdfColors.white.shade(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white.shade(0.3),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  staff['id'],
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPersonalSection(Map<String, dynamic> staff) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Personal Information'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _buildInfoRow('Full Name', staff['name']),
              pw.Divider(),
              _buildInfoRow('Date of Birth', '15 Jan 1985'),
              pw.Divider(),
              _buildInfoRow('Gender', 'Male'),
              pw.Divider(),
              _buildInfoRow('Mobile Number', staff['phone']),
              pw.Divider(),
              _buildInfoRow('Email Address', staff['email']),
              pw.Divider(),
              _buildInfoRow('Address',
                  '123, Green Valley, Sector 5, Dehradun, Uttarakhand - 248001'),
              pw.Divider(),
              _buildInfoRow('Emergency Contact', 'Ravi Kumar'),
              pw.Divider(),
              _buildInfoRow('Emergency Number', '+91 98765 00000'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildProfessionalSection(Map<String, dynamic> staff) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Professional Information'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _buildInfoRow('Designation', staff['role']),
              pw.Divider(),
              _buildInfoRow('Department', staff['department']),
              pw.Divider(),
              _buildInfoRow('Date of Joining', '01 Aug 2018'),
              pw.Divider(),
              _buildInfoRow('Employment Type', 'Permanent'),
              pw.Divider(),
              _buildInfoRow('Reporting To', 'Dr. Sneha Patel (HOD)'),
              pw.Divider(),
              _buildInfoRow('Employee Code', staff['id']),
              pw.Divider(),
              _buildInfoRow('Status', staff['status']),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSalarySection(Map<String, dynamic> staff) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Salary & Payroll Details'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#D1FAE5'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Net Monthly Salary',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromHex('#059669'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '₹85,000',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#059669'),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _buildInfoRow('Basic Salary', '₹60,000'),
              pw.Divider(),
              _buildInfoRow('House Rent Allowance', '₹20,000'),
              pw.Divider(),
              _buildInfoRow('Travel Allowance', '₹5,000'),
              pw.Divider(),
              _buildInfoRow('Medical Allowance', '₹3,000'),
              pw.Divider(),
              _buildInfoRow('Provident Fund (Deduction)', '- ₹3,000'),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Bank Details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              _buildInfoRow('Account Number', '1234567890123'),
              pw.Divider(),
              _buildInfoRow('IFSC Code', 'SBIN0001234'),
              pw.Divider(),
              _buildInfoRow('PAN Number', 'ABCDE1234F'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDocumentsSection(Map<String, dynamic> staff) {
    final documents = [
      {'name': 'Aadhaar Card', 'status': 'Uploaded'},
      {'name': 'PAN Card', 'status': 'Uploaded'},
      {'name': 'Degree Certificate', 'status': 'Uploaded'},
      {'name': 'Experience Letter', 'status': 'Pending'},
      {'name': 'Offer Letter', 'status': 'Uploaded'},
      {'name': 'Joining Letter', 'status': 'Uploaded'},
      {'name': 'Profile Photo', 'status': 'Pending'},
      {'name': 'Resume/CV', 'status': 'Uploaded'},
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Documents Status'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: documents.map((doc) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      doc['name']!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: doc['status'] == 'Uploaded'
                            ? PdfColor.fromHex('#D1FAE5')
                            : PdfColor.fromHex('#FEF3C7'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        doc['status']!,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: doc['status'] == 'Uploaded'
                              ? PdfColor.fromHex('#059669')
                              : PdfColor.fromHex('#F59E0B'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildExperienceSection(Map<String, dynamic> staff) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Education & Experience'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _buildInfoRow(
                  'Highest Qualification', 'Ph.D. in Computer Science'),
              pw.Divider(),
              _buildInfoRow('Passing Year', '2015'),
              pw.Divider(),
              _buildInfoRow('University', 'IIT Delhi'),
              pw.Divider(),
              _buildInfoRow('Total Experience', '12 Years'),
              pw.SizedBox(height: 12),
              pw.Text(
                'Work History',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildExperienceItem(
                  'Shivalik College', 'Professor', '2018 - Present'),
              _buildExperienceItem(
                  'ABC University', 'Associate Professor', '2015 - 2018'),
              _buildExperienceItem(
                  'XYZ Institute', 'Assistant Professor', '2012 - 2015'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildActivitySection(Map<String, dynamic> staff) {
    final activities = [
      {
        'title': 'Profile Updated',
        'description': 'Contact information changed',
        'time': '2 hours ago'
      },
      {
        'title': 'Salary Revised',
        'description': 'Annual increment applied',
        'time': '1 week ago'
      },
      {
        'title': 'Document Uploaded',
        'description': 'PAN Card uploaded successfully',
        'time': '2 weeks ago'
      },
      {
        'title': 'Status Changed',
        'description': 'Status updated to Active',
        'time': '1 month ago'
      },
      {
        'title': 'Department Transfer',
        'description': 'Moved to Computer Science',
        'time': '3 months ago'
      },
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recent Activity Timeline'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: activities.map((activity) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      activity['title']!,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      activity['description']!,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      activity['time']!,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey500,
                      ),
                    ),
                    if (activity != activities.last) pw.Divider(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Helper Methods
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F3F4F6'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1F2937'),
        ),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExperienceItem(
      String company, String role, String duration) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            role,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            company,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            duration,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Generated on: ${DateTime.now().toString().split('.')[0]}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
}
