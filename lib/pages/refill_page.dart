// pages/refill_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_back_button.dart';
import '../widgets/cart_icon_button.dart';
import 'bottomnav.dart';
import '../models/refill_medicine.dart';
import '../services/refill_api_service.dart';

class RefillPage extends StatefulWidget {
  const RefillPage({super.key});

  @override
  RefillPageState createState() => RefillPageState();
}

class RefillPageState extends State<RefillPage> {
  List<RefillMedicine> refillableMedicines = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRefillableMedicines();
  }

  Future<void> _loadRefillableMedicines() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Simulate API delay with potential network error
      await Future.delayed(Duration(seconds: 1));

   
      final dummyMedicines = [
        RefillMedicine(
          id: 1,
          name: 'Paracetamol 500mg',
          description: 'Pain relief and fever reducer',
          dosage: '500mg tablets',
          price: '15.50',
          thumbnail:
              'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=200&h=200&fit=crop&crop=center',
          category: 'Pain Relief',
          lastPurchased: '2 weeks ago',
          isRefillable: true,
          quantityInStock: 50,
        ),
        RefillMedicine(
          id: 2,
          name: 'Amoxicillin 250mg',
          description: 'Antibiotic for bacterial infections',
          dosage: '250mg capsules',
          price: '25.00',
          thumbnail:
              'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=200&h=200&fit=crop&crop=center',
          category: 'Antibiotics',
          lastPurchased: '1 month ago',
          isRefillable: true,
          quantityInStock: 30,
        ),
        RefillMedicine(
          id: 3,
          name: 'Vitamin D3 1000IU',
          description: 'Essential vitamin for bone health',
          dosage: '1000IU tablets',
          price: '18.75',
          thumbnail:
              'https://images.unsplash.com/photo-1550572017-edd951aa0b65?w=200&h=200&fit=crop&crop=center',
          category: 'Vitamins',
          lastPurchased: '3 weeks ago',
          isRefillable: true,
          quantityInStock: 25,
        ),
        RefillMedicine(
          id: 4,
          name: 'Ibuprofen 400mg',
          description: 'Anti-inflammatory pain relief',
          dosage: '400mg tablets',
          price: '22.30',
          thumbnail:
              'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=200&h=200&fit=crop&crop=center',
          category: 'Pain Relief',
          lastPurchased: '1 week ago',
          isRefillable: true,
          quantityInStock: 40,
        ),
        RefillMedicine(
          id: 5,
          name: 'Omeprazole 20mg',
          description: 'Proton pump inhibitor for acid reflux',
          dosage: '20mg capsules',
          price: '35.00',
          thumbnail:
              'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=200&h=200&fit=crop&crop=center',
          category: 'Digestive Health',
          lastPurchased: '2 months ago',
          isRefillable: true,
          quantityInStock: 20,
        ),
      ];

      // Validate data before setting
      if (dummyMedicines.isEmpty) {
        throw Exception('No refillable medicines found');
      }

      // Check if widget is still mounted before updating state
      if (mounted) {
        setState(() {
          refillableMedicines = dummyMedicines;
          isLoading = false;
        });
      }

      // Uncomment the lines below to use real API instead of dummy data
      // try {
      //   final medicines = await RefillApiService.getRefillableMedicines();
      //   if (mounted) {
      //     setState(() {
      //       refillableMedicines = medicines;
      //       isLoading = false;
      //     });
      //   }
      // } catch (apiError) {
      //   throw Exception('Failed to fetch medicines from server: ${apiError.toString()}');
      // }
    } on FormatException catch (e) {
      // Handle data format errors
      _handleError(
          'Invalid data format received: ${e.message}', 'Data Format Error');
    } on TimeoutException {
      // Handle timeout errors
      _handleError('Request timed out. Please check your internet connection.',
          'Connection Timeout');
    } on SocketException {

      _handleError(
          'No internet connection. Please check your network settings.',
          'No Internet Connection');
    } on HttpException catch (e) {
   
      _handleError('Server error occurred: ${e.message}', 'Server Error');
    } on Exception catch (e) {
     
      _handleError('Failed to load refillable medicines: ${e.toString()}',
          'Loading Error');
    } catch (e) {
    
      _handleError(
          'An unexpected error occurred: ${e.toString()}', 'Unexpected Error');
    }
  }

  void _handleError(String message, String title) {
    if (mounted) {
      setState(() {
        errorMessage = message;
        isLoading = false;
      });

      // Show detailed error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _loadRefillableMedicines(),
          ),
        ),
      );
    }
  }

  Future<void> _addToCart(RefillMedicine medicine) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Adding ${medicine.name} to cart...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Simulate API call with potential errors
      await Future.delayed(Duration(seconds: 1));

      // Simulate potential errors for testing
      // Uncomment the line below to test error handling
      // throw Exception('Server temporarily unavailable');

      // Use the product ID for the refill-cart API
      final success = await RefillApiService.addToCartForRefill(medicine.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${medicine.name} added to cart for refill',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Navigate to cart page
              },
            ),
          ),
        );
      } else {
        throw Exception(
            'Unable to add medicine to cart. Please try again or contact support if the problem persists.');
      }
    } on TimeoutException {
      _handleAddToCartError(
          medicine, 'Connection timeout. Try again.', 'Timeout');
    } on SocketException {
      _handleAddToCartError(medicine, 'No internet connection.', 'No Internet');
    } on HttpException {
      _handleAddToCartError(
          medicine, 'Server unavailable. Try again.', 'Server Error');
    } on FormatException {
      _handleAddToCartError(medicine, 'Processing error. Try again.', 'Error');
    } on Exception catch (e) {
      // Check if it's our custom error message
      if (e.toString().contains('Unable to add medicine to cart')) {
        _handleAddToCartError(
            medicine, 'Cannot add to cart. Try again.', 'Add Failed');
      } else {
        _handleAddToCartError(medicine, 'Failed to add to cart.', 'Error');
      }
    } catch (e) {
      _handleAddToCartError(medicine, 'Something went wrong.', 'Error');
    }
  }

  void _handleAddToCartError(
      RefillMedicine medicine, String message, String title) {
    if (!mounted) return;

    // Determine the appropriate icon based on error type
    IconData errorIcon = Icons.error_outline;
    Color backgroundColor = Colors.red.shade600;

    if (title.contains('Timeout') || title.contains('Connection')) {
      errorIcon = Icons.wifi_off;
      backgroundColor = Colors.orange.shade600;
    } else if (title.contains('Server')) {
      errorIcon = Icons.cloud_off;
      backgroundColor = Colors.red.shade700;
    } else if (title.contains('Cannot Add')) {
      errorIcon = Icons.remove_shopping_cart;
      backgroundColor = Colors.amber.shade700;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              errorIcon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _addToCart(medicine),
        ),
      ),
    );
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
                            'Tap any medicine to add directly to cart',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Checking for refillable medicines...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Medicines',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadRefillableMedicines(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (refillableMedicines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Refillable Medicines',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t purchased any refillable\nmedicines yet.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Once you purchase refillable medicines,\nthey will appear here for easy reordering.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: refillableMedicines.length,
      itemBuilder: (context, index) {
        final medicine = refillableMedicines[index];
        return _buildMedicineCard(medicine, index);
      },
    );
  }

  Widget _buildMedicineCard(RefillMedicine medicine, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addToCart(medicine),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: medicine.thumbnail.isNotEmpty
                        ? Image.network(
                            medicine.thumbnail,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.medication,
                                color: Colors.grey.shade400,
                                size: 24,
                              );
                            },
                          )
                        : Icon(
                            Icons.medication,
                            color: Colors.grey.shade400,
                            size: 24,
                          ),
                  ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₵${double.parse(medicine.price).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add to cart button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
