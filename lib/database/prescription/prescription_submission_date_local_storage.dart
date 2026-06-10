import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists client-side upload timestamps keyed by prescription id.
abstract class PrescriptionSubmissionDateLocalStorage {
  Future<Map<String, String>> readAll();
  Future<void> save(String prescriptionId, DateTime uploadedAt);
}

class PrescriptionSubmissionDateLocalStorageImpl
    implements PrescriptionSubmissionDateLocalStorage {
  static const _prefsKey = 'prescription_submission_dates_v1';

  @override
  Future<Map<String, String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(String prescriptionId, DateTime uploadedAt) async {
    final id = prescriptionId.trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final all = await readAll();
    all[id] = uploadedAt.toUtc().toIso8601String();
    await prefs.setString(_prefsKey, json.encode(all));
  }
}
