import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/product_model.dart';
import '../models/refill_medicine.dart';

class RefillMedicineParser {
  RefillMedicineParser._();

  static String formatLastPurchased(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Recently';
    }

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Recently';
      }
    } catch (e) {
      debugPrint('Error parsing date: $dateString - $e');
      return 'Recently';
    }
  }

  static String getProductImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(imagePath);
  }

  static dynamic decodeResponseBody({
    Map<String, dynamic>? body,
    String? rawBody,
  }) {
    if (body != null) return body;
    if (rawBody == null || rawBody.trim().isEmpty) return null;
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return null;
    }
  }

  static bool responseContainsMedicineData(dynamic decoded) {
    if (decoded is List) return true;
    if (decoded is Map) {
      return decoded['data'] is List ||
          decoded['medicines'] is List ||
          decoded['refillable_medicines'] is List ||
          decoded['refill'] is List;
    }
    return false;
  }

  static List<dynamic> medicinesDataFromRefillResponse(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      return decoded['refill'] ??
          decoded['data'] ??
          decoded['medicines'] ??
          decoded['refillable_medicines'] ??
          [];
    }
    return const [];
  }

  static int? parseIntId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      return parsed != null && parsed > 0 ? parsed : null;
    }
    return null;
  }

  static int? extractProductIdFromMedicineMap(Map<String, dynamic> medicineMap) {
    Map<String, dynamic>? nestedProduct;
    final product = medicineMap['product'];
    if (product is Map) {
      nestedProduct = Map<String, dynamic>.from(product);
    }

    return parseIntId(medicineMap['product_id']) ??
        parseIntId(medicineMap['productID']) ??
        parseIntId(nestedProduct?['product_id']) ??
        parseIntId(nestedProduct?['id']) ??
        parseIntId(medicineMap['id']);
  }

  static List<int> cartProductIdCandidates({
    required RefillMedicine medicine,
    List<Product>? catalogProducts,
  }) {
    final ids = <int>[];
    void add(int? value) {
      if (value != null && value > 0 && !ids.contains(value)) {
        ids.add(value);
      }
    }

    add(medicine.id);

    final catalog = catalogProducts;
    if (catalog == null || catalog.isEmpty) return ids;

    final matched = findProduct(catalog, medicine.id, medicine.name);
    add(matched?.id);
    return ids;
  }

  static List<RefillMedicine> parseRefillEndpointMedicines(
    List<dynamic> medicinesData,
  ) {
    final medicines = <RefillMedicine>[];
    for (final medicineData in medicinesData) {
      try {
        if (medicineData is! Map) continue;
        final medicineMap = Map<String, dynamic>.from(medicineData);
        final productImg = medicineMap['product_img'] ??
            medicineMap['thumbnail'] ??
            medicineMap['image'];
        final imageUrl = getProductImageUrl(productImg?.toString());

        medicines.add(RefillMedicine(
          id: extractProductIdFromMedicineMap(medicineMap) ?? 0,
          name: medicineMap['product_name'] ?? 'Unknown Medicine',
          description: medicineMap['description'] ?? '',
          dosage: medicineMap['dosage'] ?? medicineMap['route'] ?? '',
          price: (medicineMap['price'] ?? 0).toString(),
          thumbnail: imageUrl,
          category: medicineMap['category'] ?? 'Prescribed',
          lastPurchased: medicineMap['created_at'] != null
              ? formatLastPurchased(medicineMap['created_at'].toString())
              : 'Recently',
          isRefillable:
              (medicineMap['refill'] ?? '').toString().toLowerCase() ==
                  'yes',
          batchNo: medicineMap['batch_no']?.toString(),
          route: medicineMap['route']?.toString(),
          otcpom: medicineMap['otcpom']?.toString(),
          drug: medicineMap['drug']?.toString(),
          wellness: medicineMap['wellness']?.toString(),
          selfcare: medicineMap['selfcare']?.toString(),
          accessories: medicineMap['accessories']?.toString(),
          quantityInStock: medicineMap['qty_in_stock'] ??
              medicineMap['quantity_in_stock'] ??
              medicineMap['qty'] ??
              0,
        ));
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error parsing medicine: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
    return medicines;
  }

  static List<Map<String, dynamic>> filterApprovedPrescriptions(
    List<Map<String, dynamic>> prescriptions,
  ) {
    return prescriptions.where((prescription) {
      final status = prescription['status']?.toString().toLowerCase() ?? '';
      return status == 'approved' ||
          status == 'processed' ||
          status == 'completed' ||
          status == 'active' ||
          status == 'served';
    }).toList();
  }

  static Product? findProduct(
    List<Product> allProducts,
    dynamic productId,
    String? productName,
  ) {
    if (allProducts.isEmpty) return null;

    if (productId != null) {
      try {
        final id = productId is String
            ? int.tryParse(productId) ?? 0
            : productId as int? ?? 0;
        if (id > 0) {
          try {
            return allProducts.firstWhere((p) => p.id == id);
          } catch (_) {
            // ID not found, try name search
          }
        }
      } catch (_) {
        // Continue to name search
      }
    }

    if (productName != null && productName.isNotEmpty) {
      final lower = productName.toLowerCase().trim();
      try {
        return allProducts.firstWhere(
          (p) => p.name.toLowerCase().trim() == lower,
        );
      } catch (_) {
        try {
          return allProducts.firstWhere(
            (p) => p.name.toLowerCase().contains(lower),
          );
        } catch (_) {
          return null;
        }
      }
    }

    return null;
  }

  static List<RefillMedicine> parsePrescriptionMedicines({
    required List<Map<String, dynamic>> approvedPrescriptions,
    required List<Product> allProducts,
  }) {
    final medicines = <RefillMedicine>[];

    for (final prescription in approvedPrescriptions) {
      if (!prescription.containsKey('product') ||
          prescription['product'] == null) {
        debugPrint(
          '⚠️ Prescription ID ${prescription['id']} has no product/medicine data',
        );
        continue;
      }

      final productData = prescription['product'] is Map<String, dynamic>
          ? prescription['product'] as Map<String, dynamic>
          : <String, dynamic>{};

      final productId =
          prescription['product_id'] ?? productData['id'];
      final productName = prescription['product_name'] ??
          productData['name'] ??
          prescription['name'] ??
          'Prescribed Medicine';

      final matchedProduct = findProduct(allProducts, productId, productName);
      final resolvedProductId =
          matchedProduct?.id ?? parseIntId(productId) ?? 0;

      final createdAt =
          prescription['created_at'] ?? prescription['updated_at'] ?? '';
      var lastPurchased = 'Recently';
      if (createdAt.toString().isNotEmpty) {
        lastPurchased = formatLastPurchased(createdAt.toString());
      }

      final medicine = RefillMedicine(
        id: resolvedProductId,
        name: productName,
        description: productData['description'] ??
            prescription['description'] ??
            'Prescribed medicine',
        dosage: productData['dosage'] ??
            prescription['dosage'] ??
            productData['route'] ??
            '',
        price: (prescription['price'] ??
                productData['price'] ??
                matchedProduct?.price ??
                '0')
            .toString(),
        thumbnail: matchedProduct?.thumbnail != null &&
                matchedProduct!.thumbnail.isNotEmpty
            ? getProductImageUrl(matchedProduct.thumbnail)
            : getProductImageUrl(productData['thumbnail']?.toString()),
        category: productData['category'] ??
            prescription['category'] ??
            matchedProduct?.category ??
            'Prescribed',
        lastPurchased: lastPurchased,
        isRefillable: true,
        batchNo: prescription['batch_no']?.toString() ??
            productData['batch_no']?.toString(),
        route: productData['route']?.toString() ?? matchedProduct?.route,
        otcpom: productData['otcpom']?.toString() ?? matchedProduct?.otcpom,
        drug: productData['drug']?.toString() ?? matchedProduct?.drug,
        wellness:
            productData['wellness']?.toString() ?? matchedProduct?.wellness,
        selfcare:
            productData['selfcare']?.toString() ?? matchedProduct?.selfcare,
        accessories: productData['accessories']?.toString() ??
            matchedProduct?.accessories,
        quantityInStock: int.tryParse(matchedProduct?.quantity ?? '0') ??
            productData['qty_in_stock'] ??
            productData['quantity_in_stock'] ??
            0,
      );

      if (!medicines.any((m) => m.id == medicine.id && m.id != 0)) {
        medicines.add(medicine);
      }
    }

    return medicines;
  }

  static String? errorMessageFromAddToCartBody(String? rawBody) {
    if (rawBody == null || rawBody.trim().isEmpty) return null;
    try {
      final errorData = jsonDecode(rawBody);
      if (errorData is Map && errorData['message'] != null) {
        return errorData['message'].toString();
      }
    } catch (_) {}
    return null;
  }
}
