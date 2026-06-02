// pages/refill_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import 'bottomnav.dart';
import '../models/refill_medicine.dart';
import '../services/auth_service.dart';
import '../services/refill_catalog_service.dart';
import '../utils/app_error_utils.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/cart_provider.dart';

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
  final RefillCatalogService _refillCatalogService = RefillCatalogService();

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

      final token = await AuthService.getToken();
      final medicines = await _refillCatalogService.loadRefillableMedicines(
        authToken: token,
      );

      if (!mounted) return;
      setState(() {
        refillableMedicines = medicines;
        isLoading = false;
        errorMessage =
            medicines.isEmpty ? 'No refillable medicines found' : null;
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

      debugPrint(
          '[RefillPage] Adding medicine ${medicine.id} (${medicine.name}) to cart');
      debugPrint('  - Product ID: ${medicine.id}');
      debugPrint('  - Batch No: ${medicine.batchNo}');
      debugPrint('  - Quantity: 1 (default for refill)');

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Please log in to add items to cart');
      }

      await _refillCatalogService.addRefillToCart(
        authToken: token,
        medicine: medicine,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Sync cart after successful add
      try {
        final cartProvider =
            Provider.of<CartProvider>(context, listen: false);
        await cartProvider.syncWithApi();
      } catch (e) {
        debugPrint('Error syncing cart: $e');
      }
    } catch (e) {
      debugPrint('❌ Error adding medicine to cart: $e');
      if (!mounted) return;

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      AppErrorUtils.showSnack(context,
          'Failed to refill ${medicine.name}: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true);
    }
  }

  Widget _refillHeaderSliver() {
    return EclExpandableSliverAppBar(
      toolbarTitle: 'Refill Medicines',
      heroTitle: 'Refill Medicines',
      heroSubtitle: 'Browse and reorder your refillable medications',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CartIconButton(
            iconColor: Colors.white,
            iconSize: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMedicineSectionSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final medicine = refillableMedicines[index];
              return _buildMedicineCard(medicine, index);
            },
            childCount: refillableMedicines.length,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE5EDE8),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await _loadRefillableMedicines();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: scrollPhysics,
          slivers: [
            _refillHeaderSliver(),
            if (isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildLoadingState(),
              )
            else if (errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(),
              )
            else if (refillableMedicines.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              ..._buildMedicineSectionSlivers(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 3),
    );
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
