import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ModelsStore {
  static const String vehiclesKey = 'veiculos_v1';
  static const String fuelKeyPrefix = 'fuel_records_';

  static Future<List<Map<String, dynamic>>> loadVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(vehiclesKey);

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> loadFuelRecords(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$fuelKeyPrefix$vehicleId';
    final raw = prefs.getString(key);

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }
}