import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../models/category_fetch_result.dart';
import '../models/refill_medicine.dart';
import '../repositories/refill_repository.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/prescription_service.dart';
import '../services/product_catalog_service.dart';
import '../utils/refill_medicine_parser.dart';

class RefillCatalogService {
  RefillCatalogService({
    RefillRepository? refillRepository,
    PrescriptionService? prescriptionService,
    ProductCatalogService? productCatalogService,
    CartService? cartService,
  })  : _refillRepository = refillRepository ?? RefillRepositoryImpl(),
        _prescriptionService = prescriptionService ?? PrescriptionService(),
        _productCatalogService =
            productCatalogService ?? ProductCatalogService(),
        _cartService = cartService ?? CartService();

  final RefillRepository _refillRepository;
  final PrescriptionService _prescriptionService;
  final ProductCatalogService _productCatalogService;
  final CartService _cartService;

  Future<List<RefillMedicine>> loadRefillableMedicines({
    required String? authToken,
  }) async {
    if (authToken == null) {
      throw Exception('Please sign in to view refillable medicines');
    }

    try {
      final refillResult = await _refillRepository.fetchRefillList(
        authToken: authToken,
      );
      _rethrowTransportError(refillResult);

      debugPrint('📡 REFILL ENDPOINT RESPONSE ===');
      debugPrint('Status Code: ${refillResult.statusCode}');
      debugPrint('Response Body: ${refillResult.rawBody}');
      debugPrint('=============================');

      if (refillResult.statusCode == 200) {
        final decoded = RefillMedicineParser.decodeResponseBody(
          body: refillResult.body,
          rawBody: refillResult.rawBody,
        );
        if (RefillMedicineParser.responseContainsMedicineData(decoded)) {
          final medicinesData =
              RefillMedicineParser.medicinesDataFromRefillResponse(decoded);
          debugPrint(
            '✅ Found ${medicinesData.length} medicines from /refill endpoint',
          );
          if (medicinesData.isNotEmpty) {
            debugPrint('✅ Using /refill endpoint - contains medicine data');
            final parsed = RefillMedicineParser.parseRefillEndpointMedicines(
              medicinesData,
            );
            return _resolveCatalogProductIds(parsed);
          }
        } else {
          throw Exception('Refill endpoint does not contain medicine data');
        }
      } else {
        throw Exception(
          'Refill endpoint returned status ${refillResult.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ /refill endpoint failed, trying /view-prescription: $e');
    }

    final prescriptions = await _prescriptionService.fetchPrescriptions(
      authToken: authToken,
      timeout: const Duration(seconds: 10),
    );
    return _medicinesFromPrescriptions(prescriptions);
  }

  Future<bool> addRefillToCart({
    required String authToken,
    required RefillMedicine medicine,
  }) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    final headers = CartService.cartAuthHeaders(authToken, isLoggedIn);
    final productIds = await _cartProductIdCandidates(medicine);

    if (productIds.isEmpty) {
      throw Exception(
        'Could not resolve a catalog product for ${medicine.name}',
      );
    }

    debugPrint(
      '[RefillCatalogService] Adding medicine (${medicine.name}) '
      'with product ids: $productIds',
    );

    final authResponse = await _cartService.checkAuthWithProductCandidates(
      headers: headers,
      productIds: productIds,
      quantity: 1,
      batchNo: medicine.batchNo,
      onAttempt: ({
        required String url,
        required Map<String, String> headers,
        required String requestBody,
        required CategoryFetchResult result,
      }) {
        debugPrint('📦 Add to cart request body: $requestBody');
        debugPrint('📦 Add to cart response status: ${result.statusCode}');
        debugPrint('📦 Add to cart response body: ${result.rawBody}');
      },
    );
    _rethrowTransportError(authResponse.result);

    if (!CartService.isSuccessStatus(authResponse.result.statusCode)) {
      final message = RefillMedicineParser.errorMessageFromAddToCartBody(
            authResponse.result.rawBody,
          ) ??
          'Failed to add ${medicine.name} to cart. Please try again.';
      throw Exception(message);
    }

    return true;
  }

  Future<List<int>> _cartProductIdCandidates(RefillMedicine medicine) async {
    List<Product> catalog = const [];
    try {
      catalog = await _productCatalogService.fetchCatalogProducts();
    } catch (e) {
      debugPrint('Catalog lookup for refill add-to-cart: $e');
    }

    return RefillMedicineParser.cartProductIdCandidates(
      medicine: medicine,
      catalogProducts: catalog,
    );
  }

  Future<List<RefillMedicine>> _resolveCatalogProductIds(
    List<RefillMedicine> medicines,
  ) async {
    List<Product> catalog = const [];
    try {
      catalog = await _productCatalogService.fetchCatalogProducts();
    } catch (e) {
      debugPrint('Catalog lookup for refill list: $e');
      return medicines;
    }

    if (catalog.isEmpty) return medicines;

    return medicines.map((medicine) {
      final matched =
          RefillMedicineParser.findProduct(catalog, medicine.id, medicine.name);
      if (matched == null || matched.id == medicine.id) return medicine;
      debugPrint(
        '🔗 Refill "${medicine.name}": mapped id ${medicine.id} → catalog ${matched.id}',
      );
      return medicine.copyWith(id: matched.id);
    }).toList();
  }

  Future<List<RefillMedicine>> _medicinesFromPrescriptions(
    List<Map<String, dynamic>> prescriptions,
  ) async {
    debugPrint(
      '🔍 Fetched ${prescriptions.length} prescriptions for refill medicines',
    );

    final approvedPrescriptions =
        RefillMedicineParser.filterApprovedPrescriptions(prescriptions);
    debugPrint(
      '🔍 Found ${approvedPrescriptions.length} approved prescriptions out of ${prescriptions.length} total',
    );

    List<Product> allProducts = const [];
    try {
      allProducts = await _productCatalogService.fetchCatalogProducts();
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }

    final medicines = RefillMedicineParser.parsePrescriptionMedicines(
      approvedPrescriptions: approvedPrescriptions,
      allProducts: allProducts,
    );

    debugPrint(
      '💊 Extracted ${medicines.length} refillable medicines from ${approvedPrescriptions.length} prescriptions',
    );
    return medicines;
  }

  void _rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
