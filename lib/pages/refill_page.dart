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

  Future<void> _loadRefillableMedicines() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Check if user is logged in
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Please sign in to view refillable medicines';
          isLoading = false;
        });
        return;
      }

      // Fetch prescriptions from API
      final prescriptionResponse = await http.post(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/view-prescription'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (prescriptionResponse.statusCode != 200) {
        if (prescriptionResponse.statusCode == 401) {
          throw Exception('Your session has expired. Please log in again.');
        }
        throw Exception(
            'Failed to load prescriptions (${prescriptionResponse.statusCode})');
      }

      final prescriptionData = json.decode(prescriptionResponse.body);
      final prescriptions =
          List<Map<String, dynamic>>.from(prescriptionData['data'] ?? []);

      debugPrint(
          '🔍 Fetched ${prescriptions.length} prescriptions for refill medicines');

      // Filter only approved/processed prescriptions that contain medicines
      final approvedPrescriptions = prescriptions.where((prescription) {
        final status = prescription['status']?.toString().toLowerCase() ?? '';
        // Include approved, processed, or completed prescriptions
        return status == 'approved' ||
            status == 'processed' ||
            status == 'completed' ||
            status == 'active';
      }).toList();

      debugPrint(
          '🔍 Found ${approvedPrescriptions.length} approved prescriptions');

      // Extract medicines from prescriptions
      List<RefillMedicine> medicines = [];

      // Fetch all products to get images and details
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

      // Helper to find product by ID or name
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
        // Check if prescription has product/medicine data
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
        }
      }

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

      // Simulate API call (no refill API yet)
      await Future.delayed(Duration(seconds: 1));

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

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
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to refill ${medicine.name}: ${e.toString()}',
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addToCart(medicine),
          borderRadius: BorderRadius.circular(16),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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

                // Refill button
                Container(
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
              ],
            ),
          ),
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
