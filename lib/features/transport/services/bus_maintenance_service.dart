import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class BusMaintenanceService {
  final _supabase = Supabase.instance.client;

  // Get all buses grouped by routes
  Future<List<Map<String, dynamic>>> getRoutesWithBuses() async {
    try {
      final response = await _supabase.from('transport_routes').select('''
        *,
        transport_buses (*)
      ''');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting routes and buses: $e');
      return [];
    }
  }

  // Get all services for a bus
  Future<List<Map<String, dynamic>>> getBusServices(String busId) async {
    try {
      final response = await _supabase
          .from('bus_services')
          .select()
          .eq('bus_id', busId)
          .order('service_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting bus services: $e');
      return [];
    }
  }

  // Get fuel history for a bus
  Future<List<Map<String, dynamic>>> getFuelHistory(String busId) async {
    try {
      final response = await _supabase
          .from('bus_fuel_history')
          .select()
          .eq('bus_id', busId)
          .order('fill_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting fuel history: $e');
      return [];
    }
  }

  // Add new service
  Future<bool> addService({
    required String busId,
    required String date,
    required String type,
    required String description,
    required double cost,
    File? receiptFile,
  }) async {
    try {
      String? receiptUrl;

      // Upload receipt if provided
      if (receiptFile != null) {
        final ext = receiptFile.path.split('.').last;
        final fileName = 'service_${busId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('bus-maintenance').upload(fileName, receiptFile);
        receiptUrl = _supabase.storage.from('bus-maintenance').getPublicUrl(fileName);
      }

      await _supabase.from('bus_services').insert({
        'bus_id': busId,
        'service_date': date,
        'service_type': type,
        'description': description,
        'cost': cost,
        'receipt_url': receiptUrl,
      });
      return true;
    } catch (e) {
      print('Error adding bus service: $e');
      return false;
    }
  }

  // Add new fuel entry
  Future<bool> addFuelEntry({
    required String busId,
    required String date,
    required double liters,
    required double cost,
    required double odometer,
    File? receiptFile,
  }) async {
    try {
      String? receiptUrl;

      // Upload receipt if provided
      if (receiptFile != null) {
        final ext = receiptFile.path.split('.').last;
        final fileName = 'fuel_${busId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('bus-maintenance').upload(fileName, receiptFile);
        receiptUrl = _supabase.storage.from('bus-maintenance').getPublicUrl(fileName);
      }

      // Get previous fuel entry to calculate mileage
      final history = await getFuelHistory(busId);
      double? prevOdometer;
      double? calculatedMileage;

      if (history.isNotEmpty) {
        final lastEntry = history.first;
        prevOdometer = (lastEntry['odometer_reading'] as num).toDouble();
        
        if (odometer > prevOdometer && liters > 0) {
          calculatedMileage = (odometer - prevOdometer) / liters;
        }
      }

      await _supabase.from('bus_fuel_history').insert({
        'bus_id': busId,
        'fill_date': date,
        'fuel_liters': liters,
        'cost': cost,
        'odometer_reading': odometer,
        'previous_odometer': prevOdometer,
        'mileage_calculated': calculatedMileage,
        'receipt_url': receiptUrl,
      });
      return true;
    } catch (e) {
      print('Error adding fuel entry: $e');
      return false;
    }
  }
}
