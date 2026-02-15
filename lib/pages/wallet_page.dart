// pages/wallet_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/wallet_provider.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecard_widget.dart';
import 'app_back_button.dart';
import '../services/auth_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _contentAnimation;

  final TextEditingController _amountController = TextEditingController();

  // user data for the e-card
  String _userName = 'ECL USER';
  String _userEmail = '';
  String _userPhone = '';
  int? _userId;

  // get the right currency symbol for this platform
  String get _currencySymbol {
    // ios handles unicode better, android sometimes cant show the ghana cedi symbol
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return '₵'; // Use Ghana Cedi symbol on iOS
    } else {
      return 'GHS '; // Use GHS text on Android and other platforms
    }
  }

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _contentAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutQuart,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWallet();
      _startAnimations();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentAnimationController.forward();
    });
  }

  Future<void> _initializeWallet() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (!walletProvider.isInitialized) {
      await walletProvider.initialize();
    }

    // load user data for the e-card
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      debugPrint('🔍 Loaded user data: $userData');
      if (userData != null) {
        setState(() {
          _userName = userData['name'] ?? 'ECL USER';
          _userEmail = userData['email'] ?? '';
          _userPhone = userData['phone'] ?? '';
          _userId = userData['id'];
        });
        debugPrint(
            '👤 User details - ID: $_userId, Name: $_userName, Email: $_userEmail, Phone: $_userPhone');
      } else {
        debugPrint('❌ No user data found');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 LOGIN CHECK: Only allow authenticated users
    return FutureBuilder<bool>(
      future: _checkAuthentication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data != true) {
          // not logged in, show login required screen
          return _buildLoginRequiredScreen(context);
        }

        // User is authenticated - show wallet
        return _buildWalletContent(context);
      },
    );
  }

  Future<bool> _checkAuthentication() async {
    try {
      return await AuthService.isLoggedIn();
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      return false;
    }
  }

  Widget _buildLoginRequiredScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'Login Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You need to be logged in to access your wallet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Go to Login',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletContent(BuildContext context) {
    final themeProvider = Provider.of<WalletProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Colors.green.shade700;
    final backgroundColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(
                    duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
              ],
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top * 0.5),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
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
                                'My Wallet',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Manage your digital wallet',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
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
            ),
          ),

          // wallet content
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _contentAnimation.value)),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // e-card widget
                  _buildECard(themeProvider),

                  const SizedBox(height: 20),

                  // Wallet Info Section
                  _buildWalletInfoSection(primaryColor, cardColor, textColor),

                  const SizedBox(height: 20),

                  // cashback info section
                  _buildCashbackInfoSection(primaryColor, cardColor, textColor),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildECard(WalletProvider walletProvider) {
    return Column(
      children: [
        // E-Card Widget
        ECardWidget(
          cardNumber: _generateCardNumber(),
          cardHolderName: _userName,
          balance: walletProvider.balance,
          currency: _currencySymbol,
          userEmail: _userEmail,
          userPhone: _userPhone,
          onTap: () {
            // add tap functionality if we need it
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ECL Digital Wallet Card'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green.shade600,
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // quick stats below the card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.08).toInt()),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSimpleStatItem(
                  'Refunds',
                  walletProvider.formatCurrency(walletProvider.totalRefunds),
                  Colors.blue.shade600,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: _buildSimpleStatItem(
                  'Cashback',
                  walletProvider.formatCurrency(walletProvider.totalCashback),
                  Colors.orange.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWalletInfoSection(
      Color primaryColor, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withAlpha((255 * 0.1).toInt()),
                  primaryColor.withAlpha((255 * 0.05).toInt()),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha((255 * 0.15).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How Your Wallet Works',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Your money, your control',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // content section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildEnhancedInfoItem(
                  Icons.refresh_rounded,
                  'Refunds & Returns',
                  'Money from cancelled orders, returns, or refunds automatically goes here',
                  Colors.blue.shade600,
                  cardColor,
                  textColor,
                ),
                const SizedBox(height: 12),
                _buildEnhancedInfoItem(
                  Icons.card_giftcard_rounded,
                  'Cashback & Rewards',
                  'Earn money back on purchases and special promotions',
                  Colors.orange.shade600,
                  cardColor,
                  textColor,
                ),
                const SizedBox(height: 12),
                _buildEnhancedInfoItem(
                  Icons.shopping_cart_rounded,
                  'Use for Payments',
                  'Spend your wallet balance on future purchases within ECL',
                  Colors.green.shade600,
                  cardColor,
                  textColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbackInfoSection(
      Color primaryColor, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade400.withAlpha((255 * 0.1).toInt()),
                  Colors.orange.shade600.withAlpha((255 * 0.05).toInt()),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        Colors.orange.shade400.withAlpha((255 * 0.15).toInt()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎁 Automatic Cashback',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Earn money back on every qualifying order',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // content section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCashbackRule(
                  Icons.check_circle_rounded,
                  'Orders over ${_currencySymbol}500',
                  'Get 5% cashback automatically',
                  Colors.green.shade600,
                  cardColor,
                  textColor,
                ),
                const SizedBox(height: 12),
                _buildCashbackRule(
                  Icons.schedule_rounded,
                  'Instant Processing',
                  'Cashback added to wallet immediately',
                  Colors.blue.shade600,
                  cardColor,
                  textColor,
                ),
                const SizedBox(height: 12),
                _buildCashbackRule(
                  Icons.shopping_cart_rounded,
                  'Use Anywhere',
                  'Spend cashback on future purchases',
                  Colors.purple.shade600,
                  cardColor,
                  textColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbackRule(
    IconData icon,
    String title,
    String description,
    Color iconColor,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withAlpha((255 * 0.03).toInt()),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor.withAlpha((255 * 0.1).toInt()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withAlpha((255 * 0.1).toInt()),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoItem(
    IconData icon,
    String title,
    String description,
    Color iconColor,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withAlpha((255 * 0.03).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withAlpha((255 * 0.1).toInt()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha((255 * 0.1).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Generate card number based on user ID
  String _generateCardNumber() {
    try {
      // Use user ID at the end, fill the rest with zeros
      String userId = _userId?.toString() ?? '1234';

      // Create 16-digit card number with user ID at the end
      String cardNumber = '0000000000000000';

      // Replace the last digits with user ID
      if (userId.length <= 16) {
        cardNumber = cardNumber.substring(0, 16 - userId.length) + userId;
      } else {
        // If user ID is too long, use last 16 digits
        cardNumber = userId.substring(userId.length - 16);
      }

      return cardNumber;
    } catch (e) {
      return '0000000000001234'; // Fallback
    }
  }
}
