import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admission Form Model
class AdmissionForm {
  final String id;
  final String? leadId;
  final String phone;

  // Personal
  final String studentName;
  final String? email;
  final DateTime? dob;
  final String? gender;
  final String? category;
  final String? aadhar;
  final String? address;
  final String? city;
  final String? state;

  // Guardian
  final String? fatherName;
  final String? fatherOccupation;
  final String? motherName;
  final String? motherOccupation;
  final String? guardianContact;
  final String? guardianEmail;

  // 10th
  final String? tenthSchool;
  final String? tenthBoard;
  final int? tenthYear;
  final String? tenthPercentage;
  final String? tenthMarksheetUrl;

  // 12th
  final String? twelfthSchool;
  final String? twelfthBoard;
  final String? twelfthStream;
  final int? twelfthYear;
  final String? twelfthPercentage;
  final String? twelfthMarksheetUrl;

  // Course
  final String? course;
  final String? session;
  final String? batch;

  // Additional Facilities
  final bool hostelRequired;
  final bool transportationRequired;

  // Payment
  final String? paymentId;
  final String paymentStatus;
  final double paymentAmount;

  // Verification
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? verificationNotes;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  AdmissionForm({
    required this.id,
    this.leadId,
    required this.phone,
    required this.studentName,
    this.email,
    this.dob,
    this.gender,
    this.category,
    this.aadhar,
    this.address,
    this.city,
    this.state,
    this.fatherName,
    this.fatherOccupation,
    this.motherName,
    this.motherOccupation,
    this.guardianContact,
    this.guardianEmail,
    this.tenthSchool,
    this.tenthBoard,
    this.tenthYear,
    this.tenthPercentage,
    this.tenthMarksheetUrl,
    this.twelfthSchool,
    this.twelfthBoard,
    this.twelfthStream,
    this.twelfthYear,
    this.twelfthPercentage,
    this.twelfthMarksheetUrl,
    this.course,
    this.session,
    this.batch,
    this.hostelRequired = false,
    this.transportationRequired = false,
    this.paymentId,
    this.paymentStatus = 'pending',
    this.paymentAmount = 1000,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedAt,
    this.verificationNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdmissionForm.fromJson(Map<String, dynamic> json) {
    return AdmissionForm(
      id: json['id'] as String,
      leadId: json['lead_id'] as String?,
      phone: json['phone'] as String,
      studentName: json['student_name'] as String,
      email: json['email'] as String?,
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      gender: json['gender'] as String?,
      category: json['category'] as String?,
      aadhar: json['aadhar'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      fatherName: json['father_name'] as String?,
      fatherOccupation: json['father_occupation'] as String?,
      motherName: json['mother_name'] as String?,
      motherOccupation: json['mother_occupation'] as String?,
      guardianContact: json['guardian_contact'] as String?,
      guardianEmail: json['guardian_email'] as String?,
      tenthSchool: json['tenth_school'] as String?,
      tenthBoard: json['tenth_board'] as String?,
      tenthYear: json['tenth_year'] as int?,
      tenthPercentage: json['tenth_percentage'] as String?,
      tenthMarksheetUrl: json['tenth_marksheet_url'] as String?,
      twelfthSchool: json['twelfth_school'] as String?,
      twelfthBoard: json['twelfth_board'] as String?,
      twelfthStream: json['twelfth_stream'] as String?,
      twelfthYear: json['twelfth_year'] as int?,
      twelfthPercentage: json['twelfth_percentage'] as String?,
      twelfthMarksheetUrl: json['twelfth_marksheet_url'] as String?,
      course: json['course'] as String?,
      session: json['session'] as String?,
      batch: json['batch'] as String?,
      hostelRequired: json['hostel_required'] as bool? ?? false,
      transportationRequired: json['transportation_required'] as bool? ?? false,
      paymentId: json['payment_id'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentAmount: (json['payment_amount'] as num?)?.toDouble() ?? 1000,
      isVerified: json['is_verified'] as bool? ?? false,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      verificationNotes: json['verification_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lead_id': leadId,
      'phone': phone,
      'student_name': studentName,
      'email': email,
      'dob': dob?.toIso8601String().split('T')[0],
      'gender': gender,
      'category': category,
      'aadhar': aadhar,
      'address': address,
      'city': city,
      'state': state,
      'father_name': fatherName,
      'father_occupation': fatherOccupation,
      'mother_name': motherName,
      'mother_occupation': motherOccupation,
      'guardian_contact': guardianContact,
      'guardian_email': guardianEmail,
      'tenth_school': tenthSchool,
      'tenth_board': tenthBoard,
      'tenth_year': tenthYear,
      'tenth_percentage': tenthPercentage,
      'tenth_marksheet_url': tenthMarksheetUrl,
      'twelfth_school': twelfthSchool,
      'twelfth_board': twelfthBoard,
      'twelfth_stream': twelfthStream,
      'twelfth_year': twelfthYear,
      'twelfth_percentage': twelfthPercentage,
      'twelfth_marksheet_url': twelfthMarksheetUrl,
      'course': course,
      'session': session,
      'batch': batch,
      'hostel_required': hostelRequired,
      'transportation_required': transportationRequired,
      'payment_id': paymentId,
      'payment_status': paymentStatus,
      'payment_amount': paymentAmount,
      'is_verified': isVerified,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'verification_notes': verificationNotes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Admission Form Service
class AdmissionFormService {
  final _supabase = Supabase.instance.client;

  /// Get form by lead ID
  Future<AdmissionForm?> getFormByLeadId(String leadId) async {
    try {
      final response = await _supabase
          .from('admission_forms')
          .select()
          .eq('lead_id', leadId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return AdmissionForm.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching form by lead: $e');
      return null;
    }
  }

  /// Get form by phone number
  Future<AdmissionForm?> getFormByPhone(String phone) async {
    try {
      final response = await _supabase
          .from('admission_forms')
          .select()
          .eq('phone', phone)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return AdmissionForm.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching form by phone: $e');
      return null;
    }
  }

  /// Get form by ID
  Future<AdmissionForm?> getFormById(String formId) async {
    try {
      final response = await _supabase
          .from('admission_forms')
          .select()
          .eq('id', formId)
          .single();

      return AdmissionForm.fromJson(response);
    } catch (e) {
      print('Error fetching form: $e');
      return null;
    }
  }

  /// Update form data
  Future<bool> updateForm(String formId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('admission_forms').update(updates).eq('id', formId);

      return true;
    } catch (e) {
      print('Error updating form: $e');
      return false;
    }
  }

  /// Upload marksheet file
  Future<String?> uploadMarksheet(File file, String phone, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${phone}_${type}_$timestamp.pdf';
      final path = 'marksheets/$filename';

      await _supabase.storage.from('admission-documents').upload(path, file);

      // Get public URL
      final url =
          _supabase.storage.from('admission-documents').getPublicUrl(path);

      return url;
    } catch (e) {
      print('Error uploading marksheet: $e');
      return null;
    }
  }

  /// Verify form
  Future<bool> verifyForm(String formId, String verifiedBy,
      {String? notes}) async {
    try {
      final response = await _supabase.rpc('verify_admission_form', params: {
        'p_form_id': formId,
        'p_verified_by': verifiedBy,
        'p_notes': notes,
      });

      return response == true;
    } catch (e) {
      // Fallback to direct update
      try {
        await _supabase.from('admission_forms').update({
          'is_verified': true,
          'verified_by': verifiedBy,
          'verified_at': DateTime.now().toIso8601String(),
          'verification_notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', formId);
        return true;
      } catch (_) {
        print('Error verifying form: $e');
        return false;
      }
    }
  }

  /// Get all forms (for admin)
  Future<List<AdmissionForm>> getAllForms({
    bool? verified,
    String? paymentStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('admission_forms').select();

      if (verified != null) {
        query = query.eq('is_verified', verified);
      }

      if (paymentStatus != null) {
        query = query.eq('payment_status', paymentStatus);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => AdmissionForm.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching forms: $e');
      return [];
    }
  }
}
