import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';

/// School ERP Super Enterprise Living Service:
/// Manages Hostel, Infirmary (Health Room), and Cafeteria Operations.
class SchoolLivingService {
  static final SchoolLivingService _instance = SchoolLivingService._internal();
  factory SchoolLivingService() => _instance;
  SchoolLivingService._internal();

  SupabaseClient get _supabase => SupabaseService.client;
  final _payrollService = SchoolPayrollService();
  static const String defaultInstituteId = 'SHIV-SCH';

  // ===========================================================================
  // 1. HOSTEL OPERATIONS (S3.1)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getHostels({String instituteId = defaultInstituteId}) async {
    try {
      final res = await _supabase
          .from('school_hostels')
          .select()
          .eq('institute_id', instituteId)
          .order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHostelRooms(String hostelId) async {
    try {
      final res = await _supabase
          .from('school_hostel_rooms')
          .select()
          .eq('hostel_id', hostelId)
          .order('room_number');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHostelAllocations({
    String? hostelId,
    String? studentId,
  }) async {
    try {
      var query = _supabase.from('school_hostel_allocations').select();
      if (hostelId != null && hostelId.isNotEmpty) {
        query = query.eq('hostel_id', hostelId);
      }
      if (studentId != null && studentId.isNotEmpty) {
        query = query.eq('student_id', studentId);
      }
      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> allocateHostelRoom({
    required String hostelId,
    required String roomId,
    required String studentId,
    required String studentName,
    required String className,
    String bedNumber = 'Bed 1',
    String? actorUsername,
  }) async {
    final allocId = 'ALLOC-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'id': allocId,
      'institute_id': defaultInstituteId,
      'hostel_id': hostelId,
      'room_id': roomId,
      'student_id': studentId,
      'student_name': studentName,
      'class_name': className,
      'bed_number': bedNumber,
      'allocated_date': DateTime.now().toIso8601String().split('T')[0],
      'status': 'Active',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_hostel_allocations').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Hostel Allocation: $studentName',
        'content': jsonEncode(payload),
        'category': 'HostelAllocation',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payrollService.logAudit(
      actorUsername: actorUsername ?? 'warden1',
      action: 'allocate',
      entity: 'hostel_allocation',
      entityId: allocId,
      newValue: payload,
    );

    return payload;
  }

  Future<List<Map<String, dynamic>>> getGatePasses({
    String? hostelId,
    String? studentId,
    String? status,
  }) async {
    try {
      var query = _supabase.from('school_gate_passes').select();
      if (hostelId != null && hostelId.isNotEmpty) {
        query = query.eq('hostel_id', hostelId);
      }
      if (studentId != null && studentId.isNotEmpty) {
        query = query.eq('student_id', studentId);
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      final res = await query.order('out_time', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createGatePass({
    required String hostelId,
    required String studentId,
    required String studentName,
    required String className,
    required DateTime outTime,
    required DateTime expectedInTime,
    required String reason,
    String? actorUsername,
  }) async {
    final passId = 'GP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final payload = {
      'id': passId,
      'institute_id': defaultInstituteId,
      'hostel_id': hostelId,
      'student_id': studentId,
      'student_name': studentName,
      'class_name': className,
      'out_time': outTime.toIso8601String(),
      'expected_in_time': expectedInTime.toIso8601String(),
      'reason': reason,
      'parent_status': 'Approved',
      'warden_status': 'Approved',
      'parent_approved_at': DateTime.now().toIso8601String(),
      'warden_approved_at': DateTime.now().toIso8601String(),
      'status': 'Active',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_gate_passes').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Gate Pass $passId ($studentName)',
        'content': jsonEncode(payload),
        'category': 'GatePass',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payrollService.logAudit(
      actorUsername: actorUsername ?? studentId,
      action: 'create',
      entity: 'gate_pass',
      entityId: passId,
      newValue: payload,
    );

    return payload;
  }

  Future<void> updateGatePassStatus({
    required String passId,
    required String status,
    DateTime? actualInTime,
    String? actorUsername,
  }) async {
    final updates = {
      'status': status,
      if (actualInTime != null) 'actual_in_time': actualInTime.toIso8601String(),
    };

    try {
      await _supabase.from('school_gate_passes').update(updates).eq('id', passId);
    } catch (_) {
      // Fallback update
      final res = await _supabase.from('school_circulars').select().eq('category', 'GatePass');
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          if (c['id'] == passId) {
            c.addAll(updates);
            await _supabase.from('school_circulars').update({'content': jsonEncode(c)}).eq('id', r['id']);
            break;
          }
        } catch (_) {}
      }
    }

    await _payrollService.logAudit(
      actorUsername: actorUsername ?? 'warden1',
      action: 'update_status',
      entity: 'gate_pass',
      entityId: passId,
      newValue: updates,
    );
  }

  Future<Map<String, dynamic>> getHostelStats() async {
    final hostels = await getHostels();
    final passes = await getGatePasses(status: 'Active');
    final allocations = await getHostelAllocations();

    int totalCapacity = 0;
    for (final h in hostels) {
      totalCapacity += (h['capacity'] as num?)?.toInt() ?? 100;
    }

    final occupied = allocations.where((a) => a['status'] == 'Active').length;
    final occPct = totalCapacity > 0 ? (occupied / totalCapacity) * 100 : 0.0;

    return {
      'total_hostels': hostels.length,
      'total_capacity': totalCapacity,
      'occupied_beds': occupied,
      'vacant_beds': totalCapacity > occupied ? totalCapacity - occupied : 0,
      'occupancy_percentage': occPct,
      'active_gate_passes': passes.length,
      'hostels': hostels,
    };
  }

  // ===========================================================================
  // 2. INFIRMARY OPERATIONS (S3.2 - Sensitive Health Records)
  // ===========================================================================

  Future<Map<String, dynamic>> getStudentHealthRecord(String studentId) async {
    final cleanId = studentId.trim().toLowerCase();
    try {
      final res = await _supabase
          .from('school_infirmary_records')
          .select()
          .eq('student_id', cleanId)
          .maybeSingle();
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (_) {}

    return <String, dynamic>{};
  }

  Future<void> saveStudentHealthRecord(Map<String, dynamic> record, {String? actorUsername}) async {
    final studentId = record['student_id']?.toString() ?? '';
    final payload = {
      'id': 'MED-${studentId.toUpperCase()}',
      'institute_id': defaultInstituteId,
      'student_id': studentId,
      'student_name': record['student_name'] ?? 'Student',
      'class_name': record['class_name'] ?? 'Class 10-A',
      'blood_group': record['blood_group'] ?? 'B+',
      'allergies': record['allergies'] ?? 'None Reported',
      'chronic_conditions': record['chronic_conditions'] ?? 'None Reported',
      'dietary_restrictions': record['dietary_restrictions'] ?? 'None',
      'emergency_contact_name': record['emergency_contact_name'] ?? 'Parent',
      'emergency_contact_phone': record['emergency_contact_phone'] ?? '+91 9876543210',
      'medical_insurance_policy': record['medical_insurance_policy'] ?? 'Standard Institutional Cover',
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_infirmary_records').upsert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Health Record: $studentId',
        'content': jsonEncode(payload),
        'category': 'InfirmaryRecord',
        'target_audience': 'Nurse',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payrollService.logAudit(
      actorUsername: actorUsername ?? 'nurse1',
      action: 'update_health_profile',
      entity: 'infirmary_record',
      entityId: studentId,
      newValue: payload,
    );
  }

  Future<List<Map<String, dynamic>>> getInfirmaryVisits({
    String? studentId,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from('school_infirmary_visits').select();
      if (studentId != null && studentId.isNotEmpty) {
        query = query.eq('student_id', studentId);
      }
      final res = await query.order('visit_time', ascending: false).limit(limit);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Fallback
    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'InfirmaryVisit')
          .order('published_at', ascending: false)
          .limit(limit);
      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          if (studentId == null || c['student_id'] == studentId) list.add(c);
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> logInfirmaryVisit({
    required String studentId,
    required String studentName,
    required String className,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    String medicineGiven = 'Paracetamol / Rest',
    String dosage = '1 Tablet (Post Meal)',
    double temperature = 98.6,
    bool admittedToBed = false,
    String status = 'Discharged',
    required String handledBy,
  }) async {
    final visitId = 'VISIT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final payload = {
      'id': visitId,
      'institute_id': defaultInstituteId,
      'student_id': studentId,
      'student_name': studentName,
      'class_name': className,
      'visit_time': DateTime.now().toIso8601String(),
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'medicine_given': medicineGiven,
      'dosage': dosage,
      'temperature': temperature,
      'admitted_to_bed': admittedToBed,
      'parent_notified': true,
      'status': status,
      'handled_by': handledBy,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_infirmary_visits').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Clinic Visit $visitId ($studentName)',
        'content': jsonEncode(payload),
        'category': 'InfirmaryVisit',
        'target_audience': 'Parent',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payrollService.logAudit(
      actorUsername: handledBy,
      action: 'log_clinic_visit',
      entity: 'infirmary_visit',
      entityId: visitId,
      newValue: payload,
    );

    return payload;
  }

  Future<List<Map<String, dynamic>>> getMedicineStock() async {
    try {
      final res = await _supabase
          .from('school_medicine_stock')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // 3. CAFETERIA OPERATIONS (S3.3)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getCafeteriaMenus({String? dayOfWeek, String? mealType}) async {
    try {
      var query = _supabase.from('school_cafeteria_menus').select();
      if (dayOfWeek != null && dayOfWeek.isNotEmpty) {
        query = query.eq('day_of_week', dayOfWeek);
      }
      if (mealType != null && mealType.isNotEmpty) {
        query = query.eq('meal_type', mealType);
      }
      final res = await query.order('meal_type');
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Resilient Baseline Menus
    return _generateDefaultMenus(dayOfWeek ?? 'Monday');
  }

  Future<List<Map<String, dynamic>>> getCanteenOrders({
    String? studentId,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from('school_canteen_orders').select();
      if (studentId != null && studentId.isNotEmpty) {
        query = query.eq('student_id', studentId);
      }
      final res = await query.order('order_time', ascending: false).limit(limit);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Fallback
    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'CanteenOrder')
          .order('published_at', ascending: false)
          .limit(limit);
      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          if (studentId == null || c['student_id'] == studentId) list.add(c);
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createCanteenOrder({
    required String studentId,
    required String studentName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final payload = {
      'id': orderId,
      'institute_id': defaultInstituteId,
      'student_id': studentId,
      'student_name': studentName,
      'items': items,
      'total_amount': totalAmount,
      'paid_from_wallet': true,
      'status': 'Completed',
      'order_time': DateTime.now().toIso8601String(),
    };

    // Deduct from wallet
    try {
      final sResp = await _supabase
          .from('school_students')
          .select('wallet_balance')
          .eq('username', studentId)
          .maybeSingle();
      final curBal = (sResp?['wallet_balance'] as num?)?.toDouble() ?? 250.0;
      final newBal = (curBal >= totalAmount) ? (curBal - totalAmount) : 0.0;
      await _supabase.from('school_students').update({'wallet_balance': newBal}).eq('username', studentId);
    } catch (_) {}

    try {
      await _supabase.from('school_canteen_orders').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Canteen Order $orderId ($studentName)',
        'content': jsonEncode(payload),
        'category': 'CanteenOrder',
        'target_audience': 'Student',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    return payload;
  }

  List<Map<String, dynamic>> _generateDefaultMenus(String day) {
    return [
      {'id': 'MN-01', 'day_of_week': day, 'meal_type': 'Breakfast', 'item_name': 'Aloo Paratha with Curd & Pickle', 'category': 'Veg', 'price': 40.0, 'is_available': true},
      {'id': 'MN-02', 'day_of_week': day, 'meal_type': 'Breakfast', 'item_name': 'Fresh Poha with Lemon & Peanuts', 'category': 'Veg', 'price': 30.0, 'is_available': true},
      {'id': 'MN-03', 'day_of_week': day, 'meal_type': 'Lunch', 'item_name': 'Special Thali: Dal Makhani, Shahi Paneer, Jeera Rice, 3 Rotis, Salad', 'category': 'Veg', 'price': 85.0, 'is_available': true},
      {'id': 'MN-04', 'day_of_week': day, 'meal_type': 'Lunch', 'item_name': 'Rajma Chawal Bowl with Mint Chutney', 'category': 'Veg', 'price': 60.0, 'is_available': true},
      {'id': 'MN-05', 'day_of_week': day, 'meal_type': 'Snacks', 'item_name': 'Grilled Vegetable Cheese Sandwich', 'category': 'Veg', 'price': 45.0, 'is_available': true},
      {'id': 'MN-06', 'day_of_week': day, 'meal_type': 'Snacks', 'item_name': 'Fresh Fruit Juice (Orange / Mixed)', 'category': 'Veg', 'price': 35.0, 'is_available': true},
      {'id': 'MN-07', 'day_of_week': day, 'meal_type': 'Dinner', 'item_name': 'Nutritious Mixed Veg Curry, Tawa Rotis & Moong Dal Khichdi', 'category': 'Veg', 'price': 75.0, 'is_available': true},
    ];
  }
}
