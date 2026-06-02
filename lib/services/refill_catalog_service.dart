import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../models/category_fetch_result.dart';
import '../models/refill_medicine.dart';
import '../repositories/refill_repository.dart';
import '../services/prescription_service.dart';
import '../services/product_catalog_service.dart';
import '../utils/refill_medicine_parser.dart';

class RefillCatalogService {
  RefillCatalogService({
    RefillRepository? refillRepository,
    PrescriptionService? prescriptionService,
    ProductCatalogService? productCatalogService,
  })  : _refillRepository = refillRepository ?? RefillRepositoryImpl(),
        _prescriptionService = prescriptionService ?? PrescriptionService(),
        _productCatalogService =
            productCatalogService ?? ProductCatalogService();

  final RefillRepository _refillRepository;
  final PrescriptionService _prescriptionService;
  final ProductCatalogService _productCatalogService;

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
            return RefillMedicineParser.parseRefillEndpointMedicines(
              medicinesData,
            );
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
    final requestBody = <String, dynamic>{
      'productID': medicine.id,
      'quantity': 1,
      if (medicine.batchNo != null && medicine.batchNo!.isNotEmpty)
        'batch_no': medicine.batchNo,
    };

    debugPrint(
      '[RefillCatalogService] Adding medicine ${medicine.id} (${medicine.name}) to cart',
    );
    debugPrint('📦 Add to cart request body: $requestBody');

    final result = await _refillRepository.addToCart(
      authToken: authToken,
      body: requestBody,
    );
    _rethrowTransportError(result);

    debugPrint('📦 Add to cart response status: ${result.statusCode}');
    debugPrint('📦 Add to cart response body: ${result.rawBody}');

    final success = result.statusCode == 200 || result.statusCode == 201;
    if (!success) {
      final message = RefillMedicineParser.errorMessageFromAddToCartBody(
            result.rawBody,
          ) ??
          'Failed to add ${medicine.name} to cart. Please try again.';
      throw Exception(message);
    }

    return true;
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
