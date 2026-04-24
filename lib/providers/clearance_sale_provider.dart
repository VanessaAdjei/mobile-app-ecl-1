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
  bool _isDisposed = false;

  // getters to access the data
  bool get isActive => _isActive;
  ClearanceSaleData? get clearanceData => _clearanceData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // how much discount they get (like 50%)
  double get discountPercentage {
    return _clearanceData?.discountPercentage ?? 50.0;
  }

  // name of the clearance sale
  String get saleName => _clearanceData?.name ?? 'Clearance Sale';

  // description of the sale
  String get saleDescription => _clearanceData?.description ?? '';

  // Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _checkClearanceSaleFromApi();
    } catch (e) {
      _error = e.toString();
      // if api fails, use what we saved locally
      await _loadClearanceStateFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // check if theres a clearance sale active from the api
  Future<void> _checkClearanceSaleFromApi() async {
    try {
      final response = await ClearanceSaleApiService.checkActiveClearanceSale();

      _isActive = response.isActive;
      _clearanceData = response.saleData != null
          ? _convertApiDataToLocalData(response.saleData!)
          : null;

      // save it locally so we can use it offline
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

  // save clearance sale info to local storage
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

  // convert api data to our local format
  ClearanceSaleData _convertApiDataToLocalData(ClearanceSaleData apiData) {
    return apiData; // Use the API data directly since they're the same structure
  }

  // turn on the clearance sale
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
      // tell the api to activate the sale
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

        // save it locally so it works offline
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

  // turn off the clearance sale
  Future<void> deactivateClearanceSale() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // tell the api to turn off the sale
      final response = await ClearanceSaleApiService.deactivateClearanceSale();

      if (response.success) {
        _isActive = false;
        _clearanceData = null;

        // remove it from local storage
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

    // check if the category is allowed (if we specified one)
    if (_clearanceData!.applicableCategories.isNotEmpty) {
      return _clearanceData!.applicableCategories.contains(category);
    }

    return true;
  }

  // figure out the clearance price
  double calculateClearancePrice(double originalPrice) {
    if (!_isActive || _clearanceData == null) return originalPrice;

    final discount = originalPrice * (_clearanceData!.discountPercentage / 100);
    return originalPrice - discount;
  }

  // get the discount text formatted nicely
  String getFormattedDiscount() {
    if (!_isActive || _clearanceData == null) return '';
    return '${_clearanceData!.discountPercentage.toInt()}% OFF';
  }

  // check if the sale is over
  bool get hasEnded {
    if (!_isActive || _clearanceData == null) return false;
    if (_clearanceData!.endDate == null) return false;
    return DateTime.now().isAfter(_clearanceData!.endDate!);
  }

  // automatically turn off the sale if its over
  Future<void> checkAndDeactivateIfEnded() async {
    if (hasEnded) {
      await deactivateClearanceSale();
    }
  }

  // reload clearance sale status from the api
  Future<void> refreshClearanceSaleStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _checkClearanceSaleFromApi();
    } catch (e) {
      _error = e.toString();
      // dont crash, just show the error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // clear the error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // clean up when done
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
