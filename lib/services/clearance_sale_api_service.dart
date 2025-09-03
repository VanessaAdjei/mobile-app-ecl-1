// services/clearance_sale_api_service.dart
// services/clearance_sale_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class ClearanceSaleApiService {
  // For testing without API - set to true to use mock data
  static const bool _useMockData = true;

  static const String _baseUrl =
      'https://your-api-domain.com/api'; // Replace with your actual API URL
  static const String _clearanceCheckEndpoint = '/clearance/check';
  static const String _clearanceProductsEndpoint = '/clearance/products';
  static const String _clearanceActivateEndpoint = '/clearance/activate';
  static const String _clearanceDeactivateEndpoint = '/clearance/deactivate';

  // Check if there's an active clearance sale
  static Future<ClearanceSaleCheckResponse> checkActiveClearanceSale() async {
    if (_useMockData) {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock response - no active sale by default
      return ClearanceSaleCheckResponse(
        isActive: false,
        saleData: null,
        message: 'No active clearance sale',
      );
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_clearanceCheckEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ClearanceSaleCheckResponse.fromJson(data);
      } else {
        throw ClearanceSaleApiException(
          'Failed to check clearance sale: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClearanceSaleApiException) {
        rethrow;
      }
      throw ClearanceSaleApiException('Network error: $e', 0);
    }
  }

  // Fetch clearance products with their discounted prices
  static Future<ClearanceProductsResponse> getClearanceProducts({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    if (_useMockData) {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Mock clearance products
      final mockProducts =
          _generateMockClearanceProducts(page, limit, category);

      return ClearanceProductsResponse(
        products: mockProducts,
        totalCount: 50, // Mock total count
        currentPage: page,
        totalPages: 3,
        hasNextPage: page < 3,
      );
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final uri = Uri.parse('$_baseUrl$_clearanceProductsEndpoint')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ClearanceProductsResponse.fromJson(data);
      } else {
        throw ClearanceSaleApiException(
          'Failed to fetch clearance products: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClearanceSaleApiException) {
        rethrow;
      }
      throw ClearanceSaleApiException('Network error: $e', 0);
    }
  }

  // Activate clearance sale (admin only)
  static Future<ClearanceSaleActivationResponse> activateClearanceSale({
    required String name,
    required String description,
    required double discountPercentage,
    List<String>? applicableCategories,
    List<String>? excludedProducts,
    DateTime? endDate,
  }) async {
    if (_useMockData) {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 600));

      // Mock successful activation
      final saleData = ClearanceSaleData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        discountPercentage: discountPercentage,
        applicableCategories: applicableCategories ?? [],
        excludedProducts: excludedProducts ?? [],
        startDate: DateTime.now(),
        endDate: endDate,
        isActive: true,
      );

      return ClearanceSaleActivationResponse(
        success: true,
        message: 'Clearance sale activated successfully!',
        saleData: saleData,
      );
    }

    try {
      final requestBody = {
        'name': name,
        'description': description,
        'discount_percentage': discountPercentage,
        'applicable_categories': applicableCategories ?? [],
        'excluded_products': excludedProducts ?? [],
        'end_date': endDate?.toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_clearanceActivateEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              // Add authorization header if needed
              // 'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return ClearanceSaleActivationResponse.fromJson(data);
      } else {
        throw ClearanceSaleApiException(
          'Failed to activate clearance sale: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClearanceSaleApiException) {
        rethrow;
      }
      throw ClearanceSaleApiException('Network error: $e', 0);
    }
  }

  // Deactivate clearance sale (admin only)
  static Future<ClearanceSaleDeactivationResponse>
      deactivateClearanceSale() async {
    if (_useMockData) {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 400));

      // Mock successful deactivation
      return ClearanceSaleDeactivationResponse(
        success: true,
        message: 'Clearance sale deactivated successfully!',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_clearanceDeactivateEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ClearanceSaleDeactivationResponse.fromJson(data);
      } else {
        throw ClearanceSaleApiException(
          'Failed to deactivate clearance sale: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClearanceSaleApiException) {
        rethrow;
      }
      throw ClearanceSaleApiException('Network error: $e', 0);
    }
  }

  // Get clearance sale banners
  static Future<List<String>> getClearanceBanners() async {
    if (_useMockData) {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Mock banners
      return [
        "https://via.placeholder.com/400x200/FF6B6B/FFFFFF?text=MEGA+CLEARANCE+SALE",
        "https://via.placeholder.com/400x200/FF8E53/FFFFFF?text=UP+TO+70%25+OFF",
        "https://via.placeholder.com/400x200/4ECDC4/FFFFFF?text=LIMITED+TIME+DEALS",
        "https://via.placeholder.com/400x200/45B7D1/FFFFFF?text=HURRY+UP+STOCK+LIMITED",
      ];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/clearance/banners'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['banners'] ?? []);
      } else {
        // Return default banners if API fails
        return [
          "https://via.placeholder.com/400x200?text=CLEARANCE+SALE",
          "https://via.placeholder.com/400x200?text=AMAZING+DEALS",
        ];
      }
    } catch (e) {
      // Return default banners if API fails
      return [
        "https://via.placeholder.com/400x200?text=CLEARANCE+SALE",
        "https://via.placeholder.com/400x200?text=AMAZING+DEALS",
      ];
    }
  }

  // Generate mock clearance products
  static List<ClearanceProduct> _generateMockClearanceProducts(
      int page, int limit, String? category) {
    final allProducts = [
      ClearanceProduct(
        id: 1,
        name: "Paracetamol 500mg",
        description: "Effective pain relief medication",
        urlName: "paracetamol-500mg",
        status: "active",
        batchNo: "B001",
        originalPrice: 15.00,
        clearancePrice: 7.50,
        discountAmount: 7.50,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/FF6B6B/FFFFFF?text=Paracetamol",
        quantity: "100",
        category: "Pain Relief",
        route: "oral",
      ),
      ClearanceProduct(
        id: 2,
        name: "Vitamin C 1000mg",
        description: "Immune system support and antioxidant",
        urlName: "vitamin-c-1000mg",
        status: "active",
        batchNo: "B002",
        originalPrice: 25.00,
        clearancePrice: 12.50,
        discountAmount: 12.50,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/4ECDC4/FFFFFF?text=Vitamin+C",
        quantity: "50",
        category: "Vitamins",
        route: "oral",
      ),
      ClearanceProduct(
        id: 3,
        name: "Ibuprofen 400mg",
        description: "Anti-inflammatory pain relief",
        urlName: "ibuprofen-400mg",
        status: "active",
        batchNo: "B003",
        originalPrice: 20.00,
        clearancePrice: 10.00,
        discountAmount: 10.00,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/FF8E53/FFFFFF?text=Ibuprofen",
        quantity: "75",
        category: "Pain Relief",
        route: "oral",
      ),
      ClearanceProduct(
        id: 4,
        name: "Multivitamin Complex",
        description: "Complete daily nutrition support",
        urlName: "multivitamin-complex",
        status: "active",
        batchNo: "B004",
        originalPrice: 35.00,
        clearancePrice: 17.50,
        discountAmount: 17.50,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/45B7D1/FFFFFF?text=Multivitamin",
        quantity: "30",
        category: "Vitamins",
        route: "oral",
      ),
      ClearanceProduct(
        id: 5,
        name: "Calcium 600mg",
        description: "Bone health and strength support",
        urlName: "calcium-600mg",
        status: "active",
        batchNo: "B005",
        originalPrice: 18.00,
        clearancePrice: 9.00,
        discountAmount: 9.00,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/96CEB4/FFFFFF?text=Calcium",
        quantity: "60",
        category: "Supplements",
        route: "oral",
      ),
      ClearanceProduct(
        id: 6,
        name: "Omega-3 Fish Oil",
        description: "Heart and brain health support",
        urlName: "omega-3-fish-oil",
        status: "active",
        batchNo: "B006",
        originalPrice: 42.00,
        clearancePrice: 21.00,
        discountAmount: 21.00,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/FFEAA7/333333?text=Omega-3",
        quantity: "25",
        category: "Supplements",
        route: "oral",
      ),
      ClearanceProduct(
        id: 7,
        name: "Aspirin 75mg",
        description: "Low dose aspirin for heart health",
        urlName: "aspirin-75mg",
        status: "active",
        batchNo: "B007",
        originalPrice: 12.00,
        clearancePrice: 6.00,
        discountAmount: 6.00,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/DDA0DD/FFFFFF?text=Aspirin",
        quantity: "80",
        category: "Pain Relief",
        route: "oral",
      ),
      ClearanceProduct(
        id: 8,
        name: "Iron Supplement",
        description: "Iron deficiency support",
        urlName: "iron-supplement",
        status: "active",
        batchNo: "B008",
        originalPrice: 22.00,
        clearancePrice: 11.00,
        discountAmount: 11.00,
        discountPercentage: 50.0,
        thumbnail:
            "https://via.placeholder.com/200x200/F8B500/FFFFFF?text=Iron",
        quantity: "40",
        category: "Supplements",
        route: "oral",
      ),
    ];

    // Filter by category if specified
    List<ClearanceProduct> filteredProducts = allProducts;
    if (category != null && category.isNotEmpty) {
      filteredProducts = allProducts
          .where(
              (p) => p.category.toLowerCase().contains(category.toLowerCase()))
          .toList();
    }

    // Apply pagination
    final startIndex = (page - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, filteredProducts.length);

    if (startIndex >= filteredProducts.length) {
      return [];
    }

    return filteredProducts.sublist(startIndex, endIndex);
  }
}

// API Models
class ClearanceSaleCheckResponse {
  final bool isActive;
  final ClearanceSaleData? saleData;
  final String? message;

  ClearanceSaleCheckResponse({
    required this.isActive,
    this.saleData,
    this.message,
  });

  factory ClearanceSaleCheckResponse.fromJson(Map<String, dynamic> json) {
    return ClearanceSaleCheckResponse(
      isActive: json['is_active'] ?? false,
      saleData: json['sale_data'] != null
          ? ClearanceSaleData.fromJson(json['sale_data'])
          : null,
      message: json['message'],
    );
  }
}

class ClearanceProductsResponse {
  final List<ClearanceProduct> products;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;

  ClearanceProductsResponse({
    required this.products,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory ClearanceProductsResponse.fromJson(Map<String, dynamic> json) {
    return ClearanceProductsResponse(
      products: (json['products'] as List)
          .map((p) => ClearanceProduct.fromJson(p))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      hasNextPage: json['has_next_page'] ?? false,
    );
  }
}

class ClearanceSaleActivationResponse {
  final bool success;
  final String message;
  final ClearanceSaleData? saleData;

  ClearanceSaleActivationResponse({
    required this.success,
    required this.message,
    this.saleData,
  });

  factory ClearanceSaleActivationResponse.fromJson(Map<String, dynamic> json) {
    return ClearanceSaleActivationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      saleData: json['sale_data'] != null
          ? ClearanceSaleData.fromJson(json['sale_data'])
          : null,
    );
  }
}

class ClearanceSaleDeactivationResponse {
  final bool success;
  final String message;

  ClearanceSaleDeactivationResponse({
    required this.success,
    required this.message,
  });

  factory ClearanceSaleDeactivationResponse.fromJson(
      Map<String, dynamic> json) {
    return ClearanceSaleDeactivationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class ClearanceSaleData {
  final String id;
  final String name;
  final String description;
  final double discountPercentage;
  final List<String> applicableCategories;
  final List<String> excludedProducts;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  ClearanceSaleData({
    required this.id,
    required this.name,
    required this.description,
    required this.discountPercentage,
    required this.applicableCategories,
    required this.excludedProducts,
    required this.startDate,
    this.endDate,
    required this.isActive,
  });

  factory ClearanceSaleData.fromJson(Map<String, dynamic> json) {
    return ClearanceSaleData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      discountPercentage: (json['discount_percentage'] ?? 0.0).toDouble(),
      applicableCategories:
          List<String>.from(json['applicable_categories'] ?? []),
      excludedProducts: List<String>.from(json['excluded_products'] ?? []),
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'discount_percentage': discountPercentage,
      'applicable_categories': applicableCategories,
      'excluded_products': excludedProducts,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
    };
  }
}

class ClearanceProduct {
  final int id;
  final String name;
  final String description;
  final String urlName;
  final String status;
  final String batchNo;
  final double originalPrice;
  final double clearancePrice;
  final double discountAmount;
  final double discountPercentage;
  final String thumbnail;
  final String quantity;
  final String category;
  final String route;
  final String? otcpom;
  final String? drug;
  final String? wellness;
  final String? selfcare;
  final String? accessories;

  ClearanceProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.urlName,
    required this.status,
    required this.batchNo,
    required this.originalPrice,
    required this.clearancePrice,
    required this.discountAmount,
    required this.discountPercentage,
    required this.thumbnail,
    required this.quantity,
    required this.category,
    required this.route,
    this.otcpom,
    this.drug,
    this.wellness,
    this.selfcare,
    this.accessories,
  });

  factory ClearanceProduct.fromJson(Map<String, dynamic> json) {
    final originalPrice = (json['original_price'] ?? 0.0).toDouble();
    final clearancePrice = (json['clearance_price'] ?? 0.0).toDouble();
    final discountAmount = originalPrice - clearancePrice;
    final discountPercentage =
        originalPrice > 0 ? (discountAmount / originalPrice) * 100 : 0.0;

    return ClearanceProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      urlName: json['url_name'] ?? '',
      status: json['status'] ?? '',
      batchNo: json['batch_no'] ?? '',
      originalPrice: originalPrice,
      clearancePrice: clearancePrice,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      thumbnail: json['thumbnail'] ?? '',
      quantity: json['quantity']?.toString() ?? '',
      category: json['category'] ?? '',
      route: json['route'] ?? '',
      otcpom: json['otcpom'],
      drug: json['drug'],
      wellness: json['wellness'],
      selfcare: json['selfcare'],
      accessories: json['accessories'],
    );
  }

  // Convert to regular Product for compatibility
  Map<String, dynamic> toProductJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'url_name': urlName,
      'status': status,
      'batch_no': batchNo,
      'price': clearancePrice.toString(),
      'thumbnail': thumbnail,
      'quantity': quantity,
      'category': category,
      'route': route,
      'otcpom': otcpom,
      'drug': drug,
      'wellness': wellness,
      'selfcare': selfcare,
      'accessories': accessories,
    };
  }
}

// Custom exception for API errors
class ClearanceSaleApiException implements Exception {
  final String message;
  final int statusCode;

  ClearanceSaleApiException(this.message, this.statusCode);

  @override
  String toString() =>
      'ClearanceSaleApiException: $message (Status: $statusCode)';
}
