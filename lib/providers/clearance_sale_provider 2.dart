// providers/clearance_sale_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/clearance_sale_api_service.dart';

class ClearanceSaleProvider extends ChangeNotifier {
  static const String _clearanceActiveKey = 'clearance_sale_active';
  static const String _clearanceDataKey = 'clearance_sale_data';

  bool _isActive = false;
  ClearanceSaleData? _clearanceData;
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isActive => _isActive;
  ClearanceSaleData? get clearanceData => _clearanceData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get clearance discount percentage
  double get discountPercentage {
    return _clearanceData?.discountPercentage ?? 50.0;
  }

  // Get clearance sale name
  String get saleName => _clearanceData?.name ?? 'Clearance Sale';

  // Get clearance sale description
  String get saleDescription => _clearanceData?.description ?? '';

  // Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _checkClearanceSaleFromApi();
    } catch (e) {
      _error = e.toString();
      // Fallback to local storage if API fails
      await _loadClearanceStateFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check clearance sale status from API
  Future<void> _checkClearanceSaleFromApi() async {
    try {
      final response = await ClearanceSaleApiService.checkActiveClearanceSale();

      _isActive = response.isActive;
      _clearanceData = response.saleData != null
          ? _convertApiDataToLocalData(response.saleData!)
          : null;

      // Cache the result locally for offline use
      await _saveClearanceStateToLocal();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to check clearance sale from API: $e';

      debugPrint('Clearance sale check error: $e');
    }
  }

  Future<void> _loadClearanceStateFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isActive = prefs.getBool(_clearanceActiveKey) ?? false;

      final clearanceDataJson = prefs.getString(_clearanceDataKey);
      if (clearanceDataJson != null) {
        final data = json.decode(clearanceDataJson);
        _clearanceData = ClearanceSaleData.fromJson(data);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load clearance state from local storage: $e';
      rethrow;
    }
  }

  // Save clearance state to local storage
  Future<void> _saveClearanceStateToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_clearanceActiveKey, _isActive);
      if (_clearanceData != null) {
        await prefs.setString(
            _clearanceDataKey, json.encode(_clearanceData!.toJson()));
      } else {
        await prefs.remove(_clearanceDataKey);
      }
    } catch (e) {
      debugPrint('Failed to save clearance state to local storage: $e');
    }
  }

  // Convert API data to local data format
  ClearanceSaleData _convertApiDataToLocalData(ClearanceSaleData apiData) {
    return apiData; // Use the API data directly since they're the same structure
  }

  // Activate clearance sale
  Future<void> activateClearanceSale({
    required String name,
    required String description,
    required double discountPercentage,
    List<String>? applicableCategories,
    List<String>? excludedProducts,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call API to activate clearance sale
      final response = await ClearanceSaleApiService.activateClearanceSale(
        name: name,
        description: description,
        discountPercentage: discountPercentage,
        applicableCategories: applicableCategories,
        excludedProducts: excludedProducts,
        endDate: endDate,
      );

      if (response.success && response.saleData != null) {
        _isActive = true;
        _clearanceData = _convertApiDataToLocalData(response.saleData!);

        // Save to local storage for offline use
        await _saveClearanceStateToLocal();

        notifyListeners();
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _error = 'Failed to activate clearance sale: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Deactivate clearance sale
  Future<void> deactivateClearanceSale() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call API to deactivate clearance sale
      final response = await ClearanceSaleApiService.deactivateClearanceSale();

      if (response.success) {
        _isActive = false;
        _clearanceData = null;

        // Remove from local storage
        await _saveClearanceStateToLocal();

        notifyListeners();
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      _error = 'Failed to deactivate clearance sale: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if product is eligible for clearance sale
  bool isProductEligible(String productId, String category) {
    if (!_isActive || _clearanceData == null) return false;

    // Check if product is excluded
    if (_clearanceData!.excludedProducts.contains(productId)) return false;

    // Check if category is applicable (if specified)
    if (_clearanceData!.applicableCategories.isNotEmpty) {
      return _clearanceData!.applicableCategories.contains(category);
    }

    return true;
  }

  // Calculate clearance price
  double calculateClearancePrice(double originalPrice) {
    if (!_isActive || _clearanceData == null) return originalPrice;

    final discount = originalPrice * (_clearanceData!.discountPercentage / 100);
    return originalPrice - discount;
  }

  // Get formatted discount text
  String getFormattedDiscount() {
    if (!_isActive || _clearanceData == null) return '';
    return '${_clearanceData!.discountPercentage.toInt()}% OFF';
  }

  // Check if clearance sale has ended
  bool get hasEnded {
    if (!_isActive || _clearanceData == null) return false;
    if (_clearanceData!.endDate == null) return false;
    return DateTime.now().isAfter(_clearanceData!.endDate!);
  }

  // Auto-deactivate if sale has ended
  Future<void> checkAndDeactivateIfEnded() async {
    if (hasEnded) {
      await deactivateClearanceSale();
    }
  }

  // Refresh clearance sale status from API
  Future<void> refreshClearanceSaleStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _checkClearanceSaleFromApi();
    } catch (e) {
      _error = e.toString();
      // Don't rethrow here, just show error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    super.dispose();
  }
}
