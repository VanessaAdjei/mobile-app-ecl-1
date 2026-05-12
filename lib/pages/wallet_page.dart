// pages/wallet_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/wallet_provider.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/ecard_widget.dart';
import '../models/wallet.dart';
import '../services/auth_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  static const int _kTransactionHistoryTabCount = 3;
  static const int _kTransactionsPerPage = 5;

  /// When true, wallet is non-interactive preview with a "Coming soon" callout.
  static const bool _kWalletPageComingSoon = true;

  // Add scroll controllers for each tab
  final ScrollController _allTransactionsController = ScrollController();
  final ScrollController _refundsController = ScrollController();
  final ScrollController _pointsController = ScrollController();
  Widget _buildECard(WalletProvider walletProvider) {
    return ECardWidget(
      cardNumber: _generateCardNumber(),
      cardHolderName: _userName,
      balance: walletProvider.balance,
      currency: _currencySymbol,
      userEmail: _userEmail,
      userPhone: _userPhone,
    );
  }

  late TabController _historyTabController;
  late AnimationController _contentAnimationController;
  late Animation<double> _contentAnimation;

  final TextEditingController _amountController = TextEditingController();

  int _historyPageAll = 0;
  int _historyPageRefunds = 0;
  int _historyPagePoints = 0;

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
    _historyTabController = TabController(
      length: _kTransactionHistoryTabCount,
      vsync: this,
    );
    super.initState();

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
  void reassemble() {
    super.reassemble();
    // Hot reload does not re-run [initState]; recreate tabs when count changes.
    _historyTabController.dispose();
    _historyTabController = TabController(
      length: _kTransactionHistoryTabCount,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _historyTabController.dispose();
    _contentAnimationController.dispose();
    _amountController.dispose();
    _allTransactionsController.dispose();
    _refundsController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _startAnimations() {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Colors.green.shade700;
    final backgroundColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          EclExpandableSliverAppBar(
            toolbarTitle: 'My Wallet',
            heroTitle: 'My Wallet',
            heroSubtitle: _kWalletPageComingSoon
                ? 'New experience · stay tuned'
                : 'Manage your digital wallet',
            actions: [
              CartIconButton(
                iconColor: Colors.white,
                iconSize: 22,
                backgroundColor: Colors.transparent,
              ),
            ],
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
              child: _kWalletPageComingSoon
                  ? _buildWalletComingSoonHero(
                      context,
                      Provider.of<WalletProvider>(context),
                      cardColor,
                      textColor,
                      primaryColor,
                      isDark,
                    )
                  : _buildWalletScrollableBody(
                      Provider.of<WalletProvider>(context),
                      cardColor,
                      textColor,
                      primaryColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletScrollableBody(
    WalletProvider themeProvider,
    Color cardColor,
    Color textColor,
    Color primaryColor,
  ) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildECard(themeProvider),
        const SizedBox(height: 10),
        _buildBalanceOverview(themeProvider, cardColor, textColor),
        const SizedBox(height: 10),
        _buildTransactionHistorySection(cardColor, textColor, primaryColor),
        const SizedBox(height: 10),
        _buildWalletInfoSection(primaryColor, cardColor, textColor),
        const SizedBox(height: 10),
        _buildCashbackInfoSection(primaryColor, cardColor, textColor),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildComingSoonCardShowcase(
      WalletProvider wallet, Color primaryColor) {
    final labelColor = Colors.grey.shade500;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'YOUR ECL WALLET CARD',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.35,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width - 44;
              final glowW = w.clamp(220.0, 420.0);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 2,
                        child: Transform.scale(
                          scaleX: 0.9,
                          scaleY: 0.26,
                          alignment: Alignment.center,
                          child: Container(
                            width: glowW,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.48),
                                  blurRadius: 44,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Transform(
                        alignment: FractionalOffset.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(-0.04)
                          ..rotateY(0.024),
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.34),
                                blurRadius: 34,
                                offset: const Offset(0, 22),
                                spreadRadius: -8,
                              ),
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.2),
                                blurRadius: 26,
                                offset: const Offset(-8, 18),
                              ),
                            ],
                          ),
                          child: ECardWidget(
                            cardNumber: _generateCardNumber(),
                            cardHolderName: _userName,
                            balance: wallet.balance,
                            currency: _currencySymbol,
                            userEmail: _userEmail,
                            userPhone: _userPhone,
                            onTap: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
            .animate()
            .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
            .scale(
              begin: const Offset(0.9, 0.9),
              duration: 520.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 10),
        Text(
          'Preview — how your card will look',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletComingSoonHero(
    BuildContext context,
    WalletProvider wallet,
    Color cardColor,
    Color textColor,
    Color primaryColor,
    bool isDark,
  ) {
    final subtleBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final minH = MediaQuery.sizeOf(context).height * 0.58;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        child: Column(
          children: [
            _buildComingSoonCardShowcase(wallet, primaryColor),
            const SizedBox(height: 28),
            Text(
              'Wallet is on the way',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We are crafting a calmer place for your balance and perks—'
              'clear, simple, and built for how you shop.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.55,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildComingSoonChip(
                  Icons.shield_outlined,
                  'Secure',
                  primaryColor,
                  subtleBorder,
                ),
                _buildComingSoonChip(
                  Icons.card_giftcard_outlined,
                  'Rewards',
                  primaryColor,
                  subtleBorder,
                ),
                _buildComingSoonChip(
                  Icons.flash_on_outlined,
                  'Instant',
                  primaryColor,
                  subtleBorder,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: cardColor,
                border: Border.all(color: subtleBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'We will notify you when the wallet is ready to use.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        height: 1.45,
                        color: textColor.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No setup needed yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonChip(
    IconData icon,
    String label,
    Color primaryColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        color: primaryColor.withValues(alpha: 0.07),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceOverview(
      WalletProvider provider, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: cardColor,
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
          Expanded(
            child: _buildSimpleStatItem(
              'Available',
              '$_currencySymbol${provider.balance.toStringAsFixed(2)}',
              Colors.green.shade700,
              fontSize: 15,
              labelFontSize: 10,
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey.shade300),
          Expanded(
            child: _buildSimpleStatItem(
              'Transactions',
              provider.transactions.length.toString(),
              textColor,
              fontSize: 15,
              labelFontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatItem(String label, String value, Color color,
      {double fontSize = 18, double labelFontSize = 12}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTransactionHistorySection(
      Color cardColor, Color textColor, Color accentColor) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final transactions = walletProvider.transactions;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  '${transactions.length} total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Track all wallet movements in one place',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: TabBar(
              controller: _historyTabController,
              labelColor: accentColor,
              unselectedLabelColor: Colors.grey.shade500,
              indicator: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelStyle: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              isScrollable: true,
              tabs: [
                _buildHistoryTab(Icons.receipt_long_rounded, 'All'),
                _buildHistoryTab(Icons.refresh_rounded, 'Refunds'),
                _buildHistoryTab(Icons.loyalty_rounded, 'Points'),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _historyTabController,
              children: [
                _buildPagedTransactionTab(
                  transactions,
                  textColor,
                  _allTransactionsController,
                  _historyPageAll,
                  (p) => setState(() {
                    _historyPageAll = p;
                    _allTransactionsController.jumpTo(0);
                  }),
                ),
                _buildPagedTransactionTab(
                  transactions
                      .where((t) =>
                          t.type == 'refund' || t.type == 'return')
                      .toList(),
                  textColor,
                  _refundsController,
                  _historyPageRefunds,
                  (p) => setState(() {
                    _historyPageRefunds = p;
                    _refundsController.jumpTo(0);
                  }),
                  emptyTitle: 'No refunds yet',
                  emptySubtitle: '',
                  emptyIcon: Icons.refresh_rounded,
                ),
                _buildPagedTransactionTab(
                  transactions
                      .where((t) =>
                          t.isPoints ||
                          t.type == 'bonus' ||
                          t.type == 'cashback')
                      .toList(),
                  textColor,
                  _pointsController,
                  _historyPagePoints,
                  (p) => setState(() {
                    _historyPagePoints = p;
                    _pointsController.jumpTo(0);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionList({
    String title = 'No transactions yet',
    String subtitle = 'Activity will appear here once your wallet is used',
    IconData icon = Icons.receipt_long_outlined,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Right column wide enough for `-GHS 999999.99` with tabular digits.
  static const double _kTransactionAmountColumnWidth = 118;

  Widget _buildTransactionListPage(
    List<WalletTransaction> pageItems,
    Color textColor,
    ScrollController controller,
  ) {
    final dividerColor = textColor.withValues(alpha: 0.08);
    final amountStyle = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      radius: const Radius.circular(10),
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        itemCount: pageItems.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: dividerColor,
        ),
        itemBuilder: (context, index) {
          final t = pageItems[index];
          final isCredit = t.isCredit;
          final iconColor = isCredit ? Colors.green : Colors.red;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    t.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: _kTransactionAmountColumnWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${isCredit ? '+' : '-'}$_currencySymbol${t.amount.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: amountStyle.copyWith(color: iconColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagedTransactionTab(
    List<WalletTransaction> transactions,
    Color textColor,
    ScrollController controller,
    int storedPage,
    void Function(int newPage) setStoredPage, {
    String? emptyTitle,
    String? emptySubtitle,
    IconData? emptyIcon,
  }) {
    if (transactions.isEmpty) {
      return _buildEmptyTransactionList(
        title: emptyTitle ?? 'No transactions yet',
        subtitle: emptySubtitle ??
            'Activity will appear here once your wallet is used',
        icon: emptyIcon ?? Icons.receipt_long_outlined,
      );
    }
    final totalPages =
        (transactions.length + _kTransactionsPerPage - 1) ~/ _kTransactionsPerPage;
    final safePage = storedPage.clamp(0, totalPages - 1);
    if (safePage != storedPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setStoredPage(safePage);
      });
    }
    final start = safePage * _kTransactionsPerPage;
    final end = start + _kTransactionsPerPage > transactions.length
        ? transactions.length
        : start + _kTransactionsPerPage;
    final pageItems = transactions.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildTransactionListPage(pageItems, textColor, controller),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 40, minHeight: 36),
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: safePage > 0
                            ? Colors.grey.shade800
                            : Colors.grey.shade400,
                      ),
                      onPressed: safePage > 0
                          ? () {
                              setStoredPage(safePage - 1);
                              controller.jumpTo(0);
                            }
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${safePage + 1} / $totalPages',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 40, minHeight: 36),
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: safePage < totalPages - 1
                            ? Colors.grey.shade800
                            : Colors.grey.shade400,
                      ),
                      onPressed: safePage < totalPages - 1
                          ? () {
                              setStoredPage(safePage + 1);
                              controller.jumpTo(0);
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab(IconData icon, String label) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildWalletInfoSection(
      Color primaryColor, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
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
                  primaryColor.withAlpha((255 * 0.1).toInt()),
                  primaryColor.withAlpha((255 * 0.05).toInt()),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
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
                          fontSize: 16,
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
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildEnhancedInfoItem(
                  Icons.refresh_rounded,
                  'Refunds',
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
        borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(18),
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
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
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
                        'Automatic Cashback',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
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
            padding: const EdgeInsets.all(18),
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
