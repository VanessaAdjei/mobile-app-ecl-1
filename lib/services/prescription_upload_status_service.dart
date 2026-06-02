import 'package:shared_preferences/shared_preferences.dart';

/// Tracks successful prescription uploads per product (local session hint).
class PrescriptionUploadStatusService {
  PrescriptionUploadStatusService._();

  static String _storageKey({
    required int productId,
    String? batchNo,
  }) {
    final batch = batchNo?.trim() ?? '';
    if (batch.isEmpty) return 'rx_uploaded_product_$productId';
    return 'rx_uploaded_product_${productId}_$batch';
  }

  static int? productIdFromItem(Map<String, dynamic>? item) {
    if (item == null) return null;
    final product = item['product'];
    if (product is Map && product['id'] != null) {
      final id = product['id'];
      if (id is int) return id;
      return int.tryParse(id.toString());
    }
    if (item['id'] != null) {
      final id = item['id'];
      if (id is int) return id;
      return int.tryParse(id.toString());
    }
    return null;
  }

  static String? batchNoFromItem(Map<String, dynamic>? item) {
    if (item == null) return null;
    final batch = item['batch_no'];
    if (batch == null) return null;
    final s = batch.toString().trim();
    return s.isEmpty ? null : s;
  }

  static Future<bool> isUploaded({
    required int productId,
    String? batchNo,
  }) async {
    if (productId <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKey(productId: productId, batchNo: batchNo)) ??
        false;
  }

  static Future<void> markUploaded({
    required int productId,
    String? batchNo,
  }) async {
    if (productId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _storageKey(productId: productId, batchNo: batchNo),
      true,
    );
  }

  static Future<void> markUploadedFromItem(Map<String, dynamic>? item) async {
    final id = productIdFromItem(item);
    if (id == null || id <= 0) return;
    await markUploaded(
      productId: id,
      batchNo: batchNoFromItem(item),
    );
  }
}
