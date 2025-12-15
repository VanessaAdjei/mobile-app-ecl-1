// pages/refill_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_back_button.dart';
import '../widgets/cart_icon_button.dart';
import 'bottomnav.dart';
import '../models/refill_medicine.dart';
import '../models/product.dart';
import 'auth_service.dart';
import 'package:provider/provider.dart';
import 'cartprovider.dart';

class RefillPage extends StatefulWidget {
  const RefillPage({super.key});

  @override
  RefillPageState createState() => RefillPageState();
}

class RefillPageState extends State<RefillPage> {
  List<RefillMedicine> refillableMedicines = [];
  bool isLoading = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRefillableMedicines();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // make the date look nice (like "2 days ago" or "Recently")
  String _formatLastPurchased(String? dateString) {
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

  // build the full url for a product image
  String _getProductImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // if its already a full url, just return it
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // if it starts with /uploads/ or /storage/, add the base url
    if (imagePath.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$imagePath';
    }

    if (imagePath.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$imagePath';
    }

    // otherwise assume its just a filename and build the full url
    // images are at: https://adm-ecommerce.ernestchemists.com.gh/uploads/product/{filename}
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$imagePath';
  }

  Future<void> _loadRefillableMedicines() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // make sure theyre logged in
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Please sign in to view refillable medicines';
          isLoading = false;
        });
        return;
      }

      // try the refill endpoint first, if that fails use the prescription one
      http.Response prescriptionResponse;
      bool useRefillEndpoint = false;

      try {
        final refillResponse = await http.get(
          Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/refill'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        debugPrint('📡 REFILL ENDPOINT RESPONSE ===');
        debugPrint('Status Code: ${refillResponse.statusCode}');
        debugPrint('Response Body: ${refillResponse.body}');
        debugPrint('=============================');

        // if we got medicines back, use them
        if (refillResponse.statusCode == 200) {
          final refillData = json.decode(refillResponse.body);
          // check if we got medicines back
          // api returns: {"status":"success","refill":[...]}
          if (refillData is List ||
              (refillData is Map &&
                  (refillData['data'] is List ||
                      refillData['medicines'] is List ||
                      refillData['refillable_medicines'] is List ||
                      refillData['refill'] is List))) {
            debugPrint('✅ Using /refill endpoint - contains medicine data');
            prescriptionResponse = refillResponse;
            useRefillEndpoint = true;
          } else {
            throw Exception('Refill endpoint does not contain medicine data');
          }
        } else {
          throw Exception(
              'Refill endpoint returned status ${refillResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('⚠️ /refill endpoint failed, trying /view-prescription: $e');
        // get prescriptions from api if refill endpoint didnt work
        prescriptionResponse = await http.post(
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/view-prescription'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      }

      debugPrint('📡 REFILL API RESPONSE ===');
      debugPrint('Status Code: ${prescriptionResponse.statusCode}');
      debugPrint('Response Headers: ${prescriptionResponse.headers}');
      debugPrint('Response Body: ${prescriptionResponse.body}');
      debugPrint('========================');

      if (prescriptionResponse.statusCode != 200) {
        if (prescriptionResponse.statusCode == 401) {
          throw Exception('Your session has expired. Please log in again.');
        }
        throw Exception(
            'Failed to load prescriptions (${prescriptionResponse.statusCode})');
      }

      final responseData = json.decode(prescriptionResponse.body);
      debugPrint('📦 Parsed Response Data:');
      debugPrint('  - Keys: ${responseData.keys}');
      debugPrint('  - Data type: ${responseData.runtimeType}');

      // check if we got medicines directly from the refill endpoint
      List<dynamic> medicinesData = [];
      if (useRefillEndpoint) {
        if (responseData is List) {
          medicinesData = responseData;
        } else if (responseData is Map<String, dynamic>) {
          // medicines come in the 'refill' key
          medicinesData = responseData['refill'] ??
              responseData['data'] ??
              responseData['medicines'] ??
              responseData['refillable_medicines'] ??
              [];
        }
        debugPrint(
            '✅ Found ${medicinesData.length} medicines from /refill endpoint');

        // print each medicine so we can see what we got
        for (int i = 0; i < medicinesData.length; i++) {
          debugPrint('💊 Medicine ${i + 1}:');
          debugPrint('  - ID: ${medicinesData[i]['id']}');
          debugPrint('  - Product ID: ${medicinesData[i]['product_id']}');
          debugPrint('  - Product Name: ${medicinesData[i]['product_name']}');
          debugPrint('  - Price: ${medicinesData[i]['price']}');
          debugPrint('  - Batch No: ${medicinesData[i]['batch_no']}');
          debugPrint('  - Status: ${medicinesData[i]['status']}');
          debugPrint('  - Refill: ${medicinesData[i]['refill']}');
          debugPrint('  - Full data: ${jsonEncode(medicinesData[i])}');
        }

        // use the medicines we got, skip the prescription stuff
        if (medicinesData.isNotEmpty) {
          // turn the api data into RefillMedicine objects
          List<RefillMedicine> medicines = [];
          for (final medicineData in medicinesData) {
            try {
              final medicineMap = medicineData as Map<String, dynamic>;
              debugPrint(
                  '🔄 Converting medicine: ${medicineMap['product_name']}');

              // convert the api data to our RefillMedicine format
              // api has: product_id, product_name, product_img, price, batch_no, etc.
              final productImg = medicineMap['product_img'] ??
                  medicineMap['thumbnail'] ??
                  medicineMap['image'];
              final imageUrl = _getProductImageUrl(productImg);

              debugPrint('🖼️ Image URL construction:');
              debugPrint('  - Original product_img: $productImg');
              debugPrint('  - Constructed URL: $imageUrl');

              final medicine = RefillMedicine(
                id: medicineMap['product_id'] ?? medicineMap['id'] ?? 0,
                name: medicineMap['product_name'] ?? 'Unknown Medicine',
                description: medicineMap['description'] ?? '',
                dosage: medicineMap['dosage'] ?? medicineMap['route'] ?? '',
                price: (medicineMap['price'] ?? 0).toString(),
                thumbnail: imageUrl,
                category: medicineMap['category'] ?? 'Prescribed',
                lastPurchased: medicineMap['created_at'] != null
                    ? _formatLastPurchased(medicineMap['created_at'])
                    : 'Recently',
                isRefillable:
                    (medicineMap['refill'] ?? '').toString().toLowerCase() ==
                        'yes',
                batchNo: medicineMap['batch_no'],
                route: medicineMap['route'],
                otcpom: medicineMap['otcpom'],
                drug: medicineMap['drug'],
                wellness: medicineMap['wellness'],
                selfcare: medicineMap['selfcare'],
                accessories: medicineMap['accessories'],
                quantityInStock: medicineMap['qty_in_stock'] ??
                    medicineMap['quantity_in_stock'] ??
                    medicineMap['qty'] ??
                    0,
              );

              debugPrint(
                  '✅ Successfully created RefillMedicine: ${medicine.name} (ID: ${medicine.id})');
              medicines.add(medicine);
            } catch (e, stackTrace) {
              debugPrint('⚠️ Error parsing medicine: $e');
              debugPrint('Stack trace: $stackTrace');
            }
          }

          if (!mounted) return;
          setState(() {
            refillableMedicines = medicines;
            isLoading = false;
            errorMessage =
                medicines.isEmpty ? 'No refillable medicines found' : null;
          });
          return; // Exit early since we got medicines directly
        }
      }

      // process prescriptions from the view-prescription endpoint
      final prescriptionData = responseData;
      if (prescriptionData['data'] != null) {
        debugPrint(
            '  - Data length: ${(prescriptionData['data'] as List).length}');
      }

      final prescriptions =
          List<Map<String, dynamic>>.from(prescriptionData['data'] ?? []);

      // print each prescription so we can see what we got
      for (int i = 0; i < prescriptions.length; i++) {
        debugPrint('📋 Prescription ${i + 1} structure:');
        debugPrint('  - Keys: ${prescriptions[i].keys}');
        debugPrint('  - Full data: ${jsonEncode(prescriptions[i])}');
      }

      debugPrint(
          '🔍 Fetched ${prescriptions.length} prescriptions for refill medicines');

      // print all the statuses so we can see what the api is sending
      for (int i = 0; i < prescriptions.length; i++) {
        final prescription = prescriptions[i];
        final status = prescription['status']?.toString() ?? 'null';
        final statusLower = status.toLowerCase();
        debugPrint(
            '📋 Prescription ${i + 1}: status="$status" (lowercase="$statusLower")');
      }

      // only show prescriptions that are approved/processed and have medicines
      // "Served" means they already got the medicine and can refill it
      final approvedPrescriptions = prescriptions.where((prescription) {
        final status = prescription['status']?.toString().toLowerCase() ?? '';
        // include these statuses: approved, processed, completed, active, or served
        final isApproved = status == 'approved' ||
            status == 'processed' ||
            status == 'completed' ||
            status == 'active' ||
            status ==
                'served'; // Add "served" status for refillable prescriptions

        if (!isApproved) {
          debugPrint(
              '❌ Prescription filtered out - status: "$status" (original: "${prescription['status']}")');
        }

        return isApproved;
      }).toList();

      debugPrint(
          '🔍 Found ${approvedPrescriptions.length} approved prescriptions out of ${prescriptions.length} total');

      // Extract medicines from prescriptions
      List<RefillMedicine> medicines = [];

      // get all products so we can get images and stuff
      List<Product> allProducts = [];
      try {
        final productsResponse = await http
            .get(Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'))
            .timeout(const Duration(seconds: 10));

        if (productsResponse.statusCode == 200) {
          final Map<String, dynamic> productsData =
              json.decode(productsResponse.body);
          final List<dynamic> productsList = productsData['data'] ?? [];
          allProducts = productsList.map<Product>((item) {
            final productData = item['product'] as Map<String, dynamic>;
            return Product(
              id: productData['id'] ?? 0,
              name: productData['name'] ?? 'No name',
              description: productData['description'] ?? '',
              urlName: productData['url_name'] ?? '',
              status: productData['status'] ?? '',
              batchNo: item['batch_no'] ?? '',
              price: (item['price'] ?? 0).toString(),
              thumbnail: productData['thumbnail'] ?? productData['image'] ?? '',
              quantity: productData['qty_in_stock']?.toString() ?? '',
              category: productData['category'] ?? '',
              route: productData['route'] ?? '',
              otcpom: productData['otcpom'],
              drug: productData['drug'],
              wellness: productData['wellness'],
              selfcare: productData['selfcare'],
              accessories: productData['accessories'],
            );
          }).toList();
        }
      } catch (e) {
        debugPrint('Error fetching products: $e');
      }

      // find a product by its id or name
      Product? findProduct(dynamic productId, String? productName) {
        if (allProducts.isEmpty) return null;

        if (productId != null) {
          try {
            final id = productId is String
                ? int.tryParse(productId) ?? 0
                : productId as int? ?? 0;
            if (id > 0) {
              try {
                return allProducts.firstWhere((p) => p.id == id);
              } catch (e) {
                // ID not found, try name search
              }
            }
          } catch (e) {
            // Continue to name search
          }
        }

        if (productName != null && productName.isNotEmpty) {
          try {
            return allProducts.firstWhere(
              (p) => p.name.toLowerCase().contains(productName.toLowerCase()),
            );
          } catch (e) {
            // Name not found, return null
            return null;
          }
        }

        return null;
      }

      // Extract medicines from prescriptions
      for (final prescription in approvedPrescriptions) {
        debugPrint('🔍 Processing prescription ID: ${prescription['id']}');
        debugPrint(
            '  - Has product field: ${prescription.containsKey('product') && prescription['product'] != null}');
        debugPrint(
            '  - Has product_id field: ${prescription.containsKey('product_id')}');
        debugPrint(
            '  - Has product_name field: ${prescription.containsKey('product_name')}');
        debugPrint(
            '  - Has medicines field: ${prescription.containsKey('medicines')}');
        debugPrint('  - Has items field: ${prescription.containsKey('items')}');

        // Check if prescription has product/medicine data
        // Note: The API response shows prescriptions only have id, file, refill, and status
        // They don't include product/medicine data, so we need to handle this case
        // For now, we'll skip prescriptions without product data and log a warning
        if (prescription.containsKey('product') &&
            prescription['product'] != null) {
          final productData = prescription['product'] is Map<String, dynamic>
              ? prescription['product'] as Map<String, dynamic>
              : {};

          final productId = prescription['product_id'] ??
              productData['id'] ??
              prescription['id'];
          final productName = prescription['product_name'] ??
              productData['name'] ??
              prescription['name'] ??
              'Prescribed Medicine';

          // Find matching product for image and details
          final matchedProduct = findProduct(productId, productName);

          // Calculate last purchased date
          final createdAt =
              prescription['created_at'] ?? prescription['updated_at'] ?? '';
          String lastPurchased = 'Recently';
          if (createdAt.isNotEmpty) {
            try {
              final date = DateTime.parse(createdAt);
              final now = DateTime.now();
              final difference = now.difference(date);
              if (difference.inDays > 0) {
                lastPurchased =
                    '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
              } else if (difference.inHours > 0) {
                lastPurchased =
                    '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
              }
            } catch (e) {
              // Keep default
            }
          }

          final medicine = RefillMedicine(
            id: productId is int
                ? productId
                : (productId is String ? int.tryParse(productId) ?? 0 : 0),
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
            thumbnail:
                matchedProduct?.thumbnail ?? productData['thumbnail'] ?? '',
            category: productData['category'] ??
                prescription['category'] ??
                matchedProduct?.category ??
                'Prescribed',
            lastPurchased: lastPurchased,
            isRefillable: true,
            batchNo: prescription['batch_no'] ?? productData['batch_no'],
            route: productData['route'] ?? matchedProduct?.route,
            otcpom: productData['otcpom'] ?? matchedProduct?.otcpom,
            drug: productData['drug'] ?? matchedProduct?.drug,
            wellness: productData['wellness'] ?? matchedProduct?.wellness,
            selfcare: productData['selfcare'] ?? matchedProduct?.selfcare,
            accessories:
                productData['accessories'] ?? matchedProduct?.accessories,
            quantityInStock: int.tryParse(matchedProduct?.quantity ?? '0') ??
                productData['qty_in_stock'] ??
                productData['quantity_in_stock'] ??
                0,
          );

          // Avoid duplicates
          if (!medicines.any((m) => m.id == medicine.id && m.id != 0)) {
            medicines.add(medicine);
          }
        } else {
          // Prescription doesn't have product data
          debugPrint(
              '⚠️ Prescription ID ${prescription['id']} has no product/medicine data');
          debugPrint(
              '  - This prescription may need to be processed first or use a different API endpoint');
          debugPrint('  - Prescription file: ${prescription['file']}');
          debugPrint('  - Prescription status: ${prescription['status']}');
        }
      }

      debugPrint(
          '💊 Extracted ${medicines.length} refillable medicines from ${approvedPrescriptions.length} prescriptions');

      if (!mounted) return;

      setState(() {
        refillableMedicines = medicines;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Failed to load refillable medicines: ${e.toString().replaceAll('Exception: ', '')}';
        isLoading = false;
      });
    }
  }

  Future<void> _addToCart(RefillMedicine medicine) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing refill...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Try using the regular cart endpoint instead of refill-cart
      // The refill-cart endpoint returns 404, so use check-auth like regular products
      debugPrint(
          '[RefillPage] Adding medicine ${medicine.id} (${medicine.name}) to cart');
      debugPrint('  - Product ID: ${medicine.id}');
      debugPrint('  - Batch No: ${medicine.batchNo}');
      debugPrint('  - Quantity: 1 (default for refill)');

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Please log in to add items to cart');
      }

      // Use the regular check-auth endpoint with productID (capital ID) like regular cart
      final requestBody = {
        'productID': medicine.id, // Use capital ID like regular cart
        'quantity': 1, // Default quantity for refill
        if (medicine.batchNo != null && medicine.batchNo!.isNotEmpty)
          'batch_no': medicine.batchNo,
      };

      debugPrint('📦 Add to cart request body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/check-auth'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📦 Add to cart response status: ${response.statusCode}');
      debugPrint('📦 Add to cart response body: ${response.body}');

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        // Sync cart after successful add
        try {
          final cartProvider =
              Provider.of<CartProvider>(context, listen: false);
          await cartProvider.syncWithApi();
        } catch (e) {
          debugPrint('Error syncing cart: $e');
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${medicine.name} refill added to cart successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade600,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        // Parse error message from response
        String errorMessage =
            'Failed to add ${medicine.name} to cart. Please try again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
          debugPrint('❌ Add to cart error: $errorMessage');
        } catch (e) {
          // Use default message
        }

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.shade600,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error adding medicine to cart: $e');
      if (!mounted) return;

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to refill ${medicine.name}: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Enhanced header with better design (matching notifications)
          Container(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.top * 0.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade700,
                  Colors.green.shade800,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    AppBackButton(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refill Medicines',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Refill your prescribed medicines',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                    CartIconButton(
                      iconColor: Colors.white,
                      iconSize: 22,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 3),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (refillableMedicines.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMedicinesList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Checking for refillable medicines...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error occurred',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  errorMessage = null;
                });
                _loadRefillableMedicines();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Refillable Medicines',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You don\'t have any approved prescribed\nmedicines available for refill yet.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only approved prescribed medicines from your prescriptions will appear here for easy refill.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildMedicinesList() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.medication_liquid,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available for Refill',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '${refillableMedicines.length} medicines ready to reorder',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${refillableMedicines.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Medicines list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: refillableMedicines.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final medicine = refillableMedicines[index];
                return _buildMedicineCard(medicine, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(RefillMedicine medicine, int index) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        top: index == 0 ? 0 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Product image with refill badge
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: medicine.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: medicine.thumbnail,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green.shade400,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.medication,
                                color: Colors.grey.shade400,
                                size: 28,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.medication,
                            color: Colors.grey.shade400,
                            size: 28,
                          ),
                  ),
                ),
                // Stock quantity badge
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '${medicine.quantityInStock}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    medicine.dosage,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'GHS ${double.parse(medicine.price).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Last: ${medicine.lastPurchased}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Refill button (only clickable element)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _addToCart(medicine),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Refill',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.0, 1.0),
            duration: 300.ms);
  }
}
