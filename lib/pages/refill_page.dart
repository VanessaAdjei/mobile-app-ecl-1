// pages/refill_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../models/refill_medicine.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/refill_catalog_service.dart';
import '../utils/app_error_utils.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/error_display.dart';

const Color _kRefillAccent = Color(0xFF0D7A4C);
const Color _kRefillPageBg = Color(0xFFF6F8FA);
const Color _kRefillPageMint = Color(0xFFEFFCF4);

class RefillPage extends StatefulWidget {
  const RefillPage({super.key});

  @override
  RefillPageState createState() => RefillPageState();
}

class RefillPageState extends State<RefillPage> with SingleTickerProviderStateMixin {
  List<RefillMedicine> refillableMedicines = [];
  bool isLoading = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();
  final RefillCatalogService _refillCatalogService = RefillCatalogService();
  TabController? _tabController;

  List<RefillMedicine> get _readyMedicines => refillableMedicines
      .where((medicine) => medicine.quantityInStock > 0)
      .toList();

  List<RefillMedicine> get _unavailableMedicines => refillableMedicines
      .where((medicine) => medicine.quantityInStock <= 0)
      .toList();

  void _ensureTabController() {
    _tabController ??= TabController(length: 2, vsync: this);
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController();
    _loadRefillableMedicines();
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = AppErrorUtils.userMessage(
          e,
          fallback: 'Could not load refillable medicines',
        );
        isLoading = false;
      });
    }
  }

  Future<void> _addToCart(RefillMedicine medicine) async {
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: _kRefillAccent,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Adding to cart…',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Please log in to add items to cart');
      }

      await _refillCatalogService.addRefillToCart(
        authToken: token,
        medicine: medicine,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      try {
        final cartProvider =
            Provider.of<CartProvider>(context, listen: false);
        await cartProvider.syncWithApi();
      } catch (e) {
        debugPrint('Error syncing cart: $e');
      }

      if (!mounted) return;
      AppErrorUtils.showSnack(
        context,
        '${medicine.name} added to cart',
        isError: false,
      );
    } catch (e) {
      debugPrint('❌ Error adding medicine to cart: $e');
      if (!mounted) return;

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      AppErrorUtils.showSnack(
        context,
        AppErrorUtils.userMessage(
          e,
          fallback: 'Failed to add ${medicine.name} to cart',
        ),
        isError: true,
      );
    }
  }

  Widget _pageBackdrop({required bool isDark, required Widget child}) {
    if (isDark) {
      return SizedBox.expand(
        child: ColoredBox(color: const Color(0xFF0F172A), child: child),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kRefillPageMint, _kRefillPageBg, _kRefillPageBg],
          stops: [0.0, 0.28, 1.0],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kRefillAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: _kRefillAccent,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading refill medicines',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Checking your approved prescriptions…',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueTabBar(bool isDark, TabController tabController) {
    final barBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Material(
      color: barBg,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kRefillAccent.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _kRefillAccent.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medication_liquid_outlined,
                    color: _kRefillAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${refillableMedicines.length} approved medicines from your prescriptions',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                unselectedLabelColor:
                    isDark ? Colors.white60 : const Color(0xFF64748B),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: 'Ready (${_readyMedicines.length})'),
                  Tab(text: 'Unavailable (${_unavailableMedicines.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : _kRefillPageBg,
      appBar: AppHeaderBar.forScaffold(
        context,
        title: 'Refill Medicines',
        subtitle: 'Reorder approved prescription items',
        showCart: true,
        background: AppHeaderBackground.accent,
      ),
      body: _pageBackdrop(
        isDark: isDark,
        child: isLoading
            ? _buildLoadingState(isDark)
            : errorMessage != null
                ? ErrorDisplay(
                    title: 'Could not load medicines',
                    message: errorMessage!,
                    showRetry: true,
                    onRetry: _loadRefillableMedicines,
                  )
                : refillableMedicines.isEmpty
                    ? _RefillEmptyState(isDark: isDark)
                    : Builder(
                        builder: (context) {
                          _ensureTabController();
                          final tabController = _tabController!;
                          return Column(
                            children: [
                              _buildQueueTabBar(isDark, tabController),
                              Expanded(
                                child: TabBarView(
                                  controller: tabController,
                                  children: [
                                    _RefillMedicineListTab(
                                      medicines: _readyMedicines,
                                      isDark: isDark,
                                      isReadyTab: true,
                                      onRefresh: _loadRefillableMedicines,
                                      onRefill: _addToCart,
                                    ),
                                    _RefillMedicineListTab(
                                      medicines: _unavailableMedicines,
                                      isDark: isDark,
                                      isReadyTab: false,
                                      onRefresh: _loadRefillableMedicines,
                                      onRefill: _addToCart,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
      ),
    );
  }
}

class _RefillEmptyState extends StatelessWidget {
  const _RefillEmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kRefillAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  size: 42,
                  color: _kRefillAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No refill medicines yet',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Approved medicines from your served prescriptions will appear here for quick reorder.',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefillMedicineListTab extends StatelessWidget {
  const _RefillMedicineListTab({
    required this.medicines,
    required this.isDark,
    required this.isReadyTab,
    required this.onRefresh,
    required this.onRefill,
  });

  final List<RefillMedicine> medicines;
  final bool isDark;
  final bool isReadyTab;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RefillMedicine medicine) onRefill;

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return RefreshIndicator(
        color: _kRefillAccent,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.42,
              child: _RefillTabEmptyState(
                isDark: isDark,
                isReadyTab: isReadyTab,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kRefillAccent,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: medicines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _RefillMedicineCard(
            medicine: medicines[index],
            isDark: isDark,
            isReadyTab: isReadyTab,
            onRefill: () => onRefill(medicines[index]),
          );
        },
      ),
    );
  }
}

class _RefillTabEmptyState extends StatelessWidget {
  const _RefillTabEmptyState({
    required this.isDark,
    required this.isReadyTab,
  });

  final bool isDark;
  final bool isReadyTab;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final accent =
        isReadyTab ? _kRefillAccent : const Color(0xFFF59E0B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isReadyTab
                      ? Icons.check_circle_outline_rounded
                      : Icons.inventory_2_outlined,
                  size: 36,
                  color: accent,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isReadyTab
                    ? 'Nothing ready to refill'
                    : 'No unavailable items',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isReadyTab
                    ? 'Medicines in stock from your prescriptions will show here.'
                    : 'Out-of-stock refill items will appear in this tab.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefillMedicineCard extends StatelessWidget {
  const _RefillMedicineCard({
    required this.medicine,
    required this.isDark,
    required this.isReadyTab,
    required this.onRefill,
  });

  final RefillMedicine medicine;
  final bool isDark;
  final bool isReadyTab;
  final VoidCallback onRefill;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final thumbBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final stripeColor =
        isReadyTab ? _kRefillAccent : const Color(0xFFF59E0B);
    final price = double.tryParse(medicine.price) ?? 0;
    final inStock = medicine.quantityInStock > 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
              blurRadius: isDark ? 16 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: thumbBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: medicine.thumbnail.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: medicine.thumbnail,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 180,
                                      memCacheHeight: 180,
                                      placeholder: (_, __) => Icon(
                                        Icons.medication_outlined,
                                        color: theme.muted,
                                      ),
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.medication_outlined,
                                        color: _kRefillAccent,
                                      ),
                                    )
                                  : Icon(
                                      Icons.medication_outlined,
                                      color: _kRefillAccent,
                                    ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: inStock
                                    ? _kRefillAccent
                                    : const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: cardBg,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '${medicine.quantityInStock}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.ink,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (medicine.dosage.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                medicine.dosage,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: theme.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'GHS ${price.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _kRefillAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (medicine.lastPurchased.isNotEmpty)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.accentTint,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.accentBorder,
                                        ),
                                      ),
                                      child: Text(
                                        'Last: ${medicine.lastPurchased}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: theme.muted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (medicine.category.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                medicine.category,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: theme.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isReadyTab)
                        _RefillActionButton(onPressed: onRefill)
                      else
                        _UnavailableBadge(isDark: isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefillActionButton extends StatelessWidget {
  const _RefillActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _kRefillAccent.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_shopping_cart_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                'Refill',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableBadge extends StatelessWidget {
  const _UnavailableBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          const SizedBox(height: 4),
          Text(
            'Out of\nstock',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF59E0B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
