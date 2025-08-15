// pages/ernest_friday_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/promotional_event.dart';
import '../providers/promotional_event_provider.dart';
import '../widgets/ernest_friday_banner.dart';
import '../widgets/promotional_code_input.dart';
import '../pages/bottomnav.dart';
import '../pages/theme_provider.dart';

class ErnestFridayPage extends StatefulWidget {
  const ErnestFridayPage({Key? key}) : super(key: key);

  @override
  State<ErnestFridayPage> createState() => _ErnestFridayPageState();
}

class _ErnestFridayPageState extends State<ErnestFridayPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  bool _isLoading = true;
  PromotionalEvent? _ernestFridayEvent;
  List<PromotionalOffer> _offers = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _loadErnestFridayData();

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Helper method to get the next Friday
  String _getNextFriday() {
    final now = DateTime.now();
    final daysUntilFriday = (DateTime.friday - now.weekday) % 7;
    if (daysUntilFriday == 0) {
      return 'Today!';
    }
    final nextFriday = now.add(Duration(days: daysUntilFriday));
    return '${nextFriday.day}/${nextFriday.month}/${nextFriday.year}';
  }

  Future<void> _loadErnestFridayData() async {
    try {
      final promotionalProvider = Provider.of<PromotionalEventProvider>(
        context,
        listen: false,
      );

      final event = await promotionalProvider.getErnestFridayEvent();
      final offers = await promotionalProvider.getErnestFridayOffers();

      if (mounted) {
        setState(() {
          _ernestFridayEvent = event;
          _offers = offers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Check if today is Friday
    final now = DateTime.now();
    final isFriday = now.weekday == DateTime.friday;

    // If not Friday, show a message that Ernest Friday is only available on Fridays
    if (!isFriday) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            '🔥 Ernest Friday',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule,
                  size: 80,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ernest Friday is Only Available on Fridays!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Come back on Friday to see our amazing slashed prices!',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(
                  'Next Ernest Friday: ${_getNextFriday()}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          '🔥 Ernest Friday',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Share Ernest Friday event
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share Ernest Friday with friends!'),
                  backgroundColor: Colors.orange.shade600,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _ernestFridayEvent == null
              ? _buildNoEventState()
              : _buildEventContent(),
      bottomNavigationBar: const CustomBottomNav(initialIndex: 0),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Ernest Friday...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Ernest Friday Event',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for upcoming events!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadErnestFridayData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Refresh',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventContent() {
    final event = _ernestFridayEvent!;

    return RefreshIndicator(
      onRefresh: _loadErnestFridayData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Main Banner
            ErnestFridayBanner(
              event: event,
              onTap: () {
                // Navigate to products or categories
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Browse Ernest Friday deals!'),
                    backgroundColor: Colors.orange.shade600,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Special Offers Section
            if (_offers.isNotEmpty) ...[
              _buildOffersSection(),
              const SizedBox(height: 20),
            ],

            // Event Details
            _buildEventDetails(event),

            const SizedBox(height: 20),

            // Promotional Code Input
            _buildPromoCodeSection(),

            const SizedBox(height: 20),

            // Shopping Categories
            _buildShoppingCategories(),

            const SizedBox(height: 20),

            // Terms and Conditions
            _buildTermsAndConditions(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Special Offers',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              final offer = _offers[index];
              return _buildOfferCard(offer, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(PromotionalOffer offer, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getOfferColor(offer.type).withAlpha((255 * 0.1).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getOfferIcon(offer.type),
              color: _getOfferColor(offer.type),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getOfferColor(offer.type)
                            .withAlpha((255 * 0.1).toInt()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        offer.formattedValue,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getOfferColor(offer.type),
                        ),
                      ),
                    ),
                    if (offer.minimumOrderAmount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Min: ₵${offer.minimumOrderAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 600.ms)
        .slideX(begin: 0.3, end: 0, delay: (index * 100).ms, duration: 600.ms);
  }

  Widget _buildEventDetails(PromotionalEvent event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 Event Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.calendar_today,
            'Start Date',
            _formatDate(event.startDate),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.timer,
            'End Date',
            _formatDate(event.endDate),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.access_time,
            'Status',
            event.isCurrentlyActive ? 'Active Now' : 'Coming Soon',
            valueColor: event.isCurrentlyActive
                ? Colors.green.shade600
                : Colors.orange.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCodeSection() {
    return PromotionalCodeInput(
      cartTotal: 0.0, // This should come from cart provider
      cartCategories: [], // This should come from cart provider
      cartProductIds: [], // This should come from cart provider
      onCodeApplied: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotional code applied successfully!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      },
      onCodeRemoved: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotional code removed'),
            backgroundColor: Colors.orange.shade600,
          ),
        );
      },
    );
  }

  Widget _buildShoppingCategories() {
    final categories = [
      {
        'name': 'Medicines',
        'icon': Icons.medication,
        'color': Colors.blue.shade600
      },
      {
        'name': 'Health & Beauty',
        'icon': Icons.face,
        'color': Colors.pink.shade600
      },
      {
        'name': 'Baby Care',
        'icon': Icons.child_care,
        'color': Colors.purple.shade600
      },
      {
        'name': 'Personal Care',
        'icon': Icons.person,
        'color': Colors.green.shade600
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🛍️ Shop by Category',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(category, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    return GestureDetector(
      onTap: () {
        // Navigate to category
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Browse ${category['name']} deals!'),
            backgroundColor: Colors.orange.shade600,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category['icon'],
              color: category['color'],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              category['name'],
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms, duration: 600.ms).scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.0, 1.0),
        delay: (index * 100).ms,
        duration: 600.ms);
  }

  Widget _buildTermsAndConditions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 Terms & Conditions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• Offers are valid only during Ernest Friday event period\n'
            '• Minimum order amounts apply to certain offers\n'
            '• Cashback will be credited to your wallet\n'
            '• Offers cannot be combined with other promotions\n'
            '• Ernest Chemists reserves the right to modify terms',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getOfferColor(String type) {
    switch (type) {
      case 'discount':
        return Colors.green.shade600;
      case 'cashback':
        return Colors.blue.shade600;
      case 'free_shipping':
        return Colors.purple.shade600;
      case 'bonus':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getOfferIcon(String type) {
    switch (type) {
      case 'discount':
        return Icons.local_offer;
      case 'cashback':
        return Icons.account_balance_wallet;
      case 'free_shipping':
        return Icons.local_shipping;
      case 'bonus':
        return Icons.card_giftcard;
      default:
        return Icons.star;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
