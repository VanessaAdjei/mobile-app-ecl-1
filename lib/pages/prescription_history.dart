// pages/prescription_history.dart
import 'package:flutter/material.dart';
import '../services/prescription_service.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/widgets/error_display.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/app_error_utils.dart';
import '../utils/prescription_parser.dart';
import '../widgets/app_header_bar.dart';

const Color _kRxAccent = Color(0xFF0D7A4C);
const Color _kRxPageBg = Color(0xFFF6F8FA);
const Color _kRxPageMint = Color(0xFFEFFCF4);

class PrescriptionHistoryScreen extends StatefulWidget {
  const PrescriptionHistoryScreen({super.key});

  static List<Map<String, dynamic>>? _cachedPrescriptions;
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  /// Clears in-memory list cache (e.g. after a new upload).
  static void invalidateCache() {
    _cachedPrescriptions = null;
    _lastFetchTime = null;
  }

  @override
  PrescriptionHistoryScreenState createState() =>
      PrescriptionHistoryScreenState();
}

class PrescriptionHistoryScreenState extends State<PrescriptionHistoryScreen>
    with SingleTickerProviderStateMixin {
  final PrescriptionService _prescriptionService = PrescriptionService();
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;

  String? _error;
  final ScrollController _scrollController = ScrollController();
  TabController? _tabController;

  // Image loading optimization
  final Map<String, bool> _imageLoadingStates = {};
  final Map<String, String?> _imageErrors = {};

  List<Map<String, dynamic>> get _pendingPrescriptions =>
      partitionPrescriptionsByQueue(_prescriptions).pending;

  List<Map<String, dynamic>> get _servedPrescriptions =>
      partitionPrescriptionsByQueue(_prescriptions).served;

  void _ensureTabController() {
    _tabController ??= TabController(length: 2, vsync: this);
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController();

    setState(() {
      _isLoading = true;
    });
    _loadPrescriptions();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrescriptions() async {
    debugPrint('🔍 Loading prescriptions...');
    // Check if we have valid cached data
    if (PrescriptionHistoryScreen._cachedPrescriptions != null &&
        PrescriptionHistoryScreen._lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now()
          .difference(PrescriptionHistoryScreen._lastFetchTime!);
      final isCacheValid =
          timeSinceLastFetch < PrescriptionHistoryScreen._cacheValidDuration;
      debugPrint(
          '🔍 Cache check: ${isCacheValid ? 'HIT' : 'MISS'} (age: ${timeSinceLastFetch.inMinutes}min)');

      if (isCacheValid) {
        setState(() {
          _prescriptions = PrescriptionHistoryScreen._cachedPrescriptions!;
          _isLoading = false;
        });
        debugPrint(
            '🔍 Loaded ${_prescriptions.length} prescriptions from cache');
        return;
      }
    }

    await _fetchPrescriptions();
  }

  Future<void> _fetchPrescriptions() async {
    try {
      debugPrint('🔍 Fetching prescriptions from API...');

      // Set loading state immediately for better perceived performance
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Please sign in to view your prescriptions';
          });
        }
        return;
      }

      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Please sign in to view your prescriptions';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final prescriptions = await _prescriptionService.fetchPrescriptions(
        authToken: token,
      );

      debugPrint(
          '🔍 Fetched ${prescriptions.length} prescriptions from API');

      PrescriptionHistoryScreen._cachedPrescriptions = prescriptions;
      PrescriptionHistoryScreen._lastFetchTime = DateTime.now();

      if (mounted) {
        setState(() {
          _prescriptions = prescriptions;
          _isLoading = false;
        });
        _preloadImages();
      }
    } catch (e) {
      AppErrorUtils.log('PrescriptionHistory._fetchPrescriptions', e);
      if (mounted) {
        setState(() {
          _error = AppErrorUtils.userMessage(
            e,
            fallback: 'Could not load prescriptions',
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPrescriptions() async {
    debugPrint('🔍 Refreshing prescriptions...');

    PrescriptionHistoryScreen.invalidateCache();

    // Show loading state immediately
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    await _fetchPrescriptions();
  }

  Widget _rxPageBackdrop({required bool isDark, required Widget child}) {
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
          colors: [_kRxPageMint, _kRxPageBg, _kRxPageBg],
          stops: [0.0, 0.28, 1.0],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final chipBg = isDark ? _kRxAccent.withValues(alpha: 0.15) : _kRxPageMint;
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: isDark ? 20 : 28,
                offset: const Offset(0, 12),
              ),
              if (!isDark)
                BoxShadow(
                  color: _kRxAccent.withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                  spreadRadius: -8,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kRxAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: _kRxAccent,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading prescriptions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fetching your prescription history…',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kRxAccent.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      color: _kRxAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Uploaded files will appear here',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _kRxAccent,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrescriptionImage(String fileUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final dlgDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final surface = dlgDark ? const Color(0xFF1E293B) : Colors.white;
        final placeholderBg =
            dlgDark ? const Color(0xFF334155) : Colors.grey.shade200;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: InteractiveViewer(
                    constrained: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: CachedNetworkImage(
                      imageUrl: fileUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 1200,
                      memCacheHeight: 1200,
                      maxWidthDiskCache: 1600,
                      maxHeightDiskCache: 1600,
                      placeholder: (context, url) => Container(
                        height: 320,
                        color: placeholderBg,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_kRxAccent),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 280,
                        color: placeholderBg,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: dlgDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Could not load image',
                                style: GoogleFonts.poppins(
                                  color: dlgDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : _kRxPageBg,
      appBar: AppHeaderBar.forScaffold(
        context,
        title: 'Uploaded Prescriptions',
        subtitle: 'Pending review and served uploads',
        showCart: false,
        background: AppHeaderBackground.accent,
      ),
      body: _rxPageBackdrop(
        isDark: isDark,
        child: _isLoading
            ? _buildLoadingSkeleton(isDark)
            : _error != null
                ? _buildErrorState()
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
                            _PrescriptionQueueTab(
                              queue: PrescriptionQueue.pending,
                              prescriptions: _pendingPrescriptions,
                              isDark: isDark,
                              onRefresh: _refreshPrescriptions,
                              onTapImage: _showPrescriptionImage,
                              emptyTitle: 'No pending prescriptions',
                              emptySubtitle:
                                  'Uploads awaiting pharmacist review will appear here.',
                            ),
                            _PrescriptionQueueTab(
                              queue: PrescriptionQueue.served,
                              prescriptions: _servedPrescriptions,
                              isDark: isDark,
                              onRefresh: _refreshPrescriptions,
                              onTapImage: _showPrescriptionImage,
                              emptyTitle: 'No served prescriptions yet',
                              emptySubtitle:
                                  'Approved, served, or completed uploads show here.',
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

  Widget _buildQueueTabBar(bool isDark, TabController tabController) {
    final pendingCount = _pendingPrescriptions.length;
    final servedCount = _servedPrescriptions.length;
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
        child: Container(
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
              Tab(text: 'Pending ($pendingCount)'),
              Tab(text: 'Served ($servedCount)'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ErrorDisplay(
      title: 'Could not load prescriptions',
      message: _error ??
          'Something went wrong. Check your connection and try again.',
      showRetry: true,
      onRetry: _refreshPrescriptions,
    );
  }

  // Preload images for better performance
  void _preloadImages() {
    for (final prescription in _prescriptions) {
      if (prescription['file'] != null) {
        final imageUrl = prescription['file'];
        if (!_imageLoadingStates.containsKey(imageUrl)) {
          _imageLoadingStates[imageUrl] = false;
          // Preload image in background
          _preloadImage(imageUrl);
        }
      }
    }
  }

  Future<void> _preloadImage(String imageUrl) async {
    try {
      _imageLoadingStates[imageUrl] = true;
      // Use a lightweight preload approach
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
        onError: (exception, stackTrace) {
          debugPrint(
              'Skipping prescription preload image (may be missing): $imageUrl');
        },
      );
      _imageLoadingStates[imageUrl] = false;
    } catch (e) {
      _imageLoadingStates[imageUrl] = false;
      _imageErrors[imageUrl] = e.toString();
    }
  }
}

class _PrescriptionQueueTab extends StatelessWidget {
  const _PrescriptionQueueTab({
    required this.queue,
    required this.prescriptions,
    required this.isDark,
    required this.onRefresh,
    required this.onTapImage,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final PrescriptionQueue queue;
  final List<Map<String, dynamic>> prescriptions;
  final bool isDark;
  final Future<void> Function() onRefresh;
  final void Function(String fileUrl) onTapImage;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (prescriptions.isEmpty) {
      return RefreshIndicator(
        color: _kRxAccent,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: _PrescriptionQueueEmptyState(
                isDark: isDark,
                queue: queue,
                title: emptyTitle,
                subtitle: emptySubtitle,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kRxAccent,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: prescriptions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _PrescriptionHistoryCard(
            prescription: prescriptions[index],
            queue: queue,
            isDark: isDark,
            onTapImage: onTapImage,
          );
        },
      ),
    );
  }
}

class _PrescriptionQueueEmptyState extends StatelessWidget {
  const _PrescriptionQueueEmptyState({
    required this.isDark,
    required this.queue,
    required this.title,
    required this.subtitle,
  });

  final bool isDark;
  final PrescriptionQueue queue;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final isPending = queue == PrescriptionQueue.pending;
    final accent = isPending ? const Color(0xFFF59E0B) : _kRxAccent;

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
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 42,
                  color: accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
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

class _PrescriptionHistoryCard extends StatelessWidget {
  const _PrescriptionHistoryCard({
    required this.prescription,
    required this.queue,
    required this.isDark,
    required this.onTapImage,
  });

  final Map<String, dynamic> prescription;
  final PrescriptionQueue queue;
  final bool isDark;
  final void Function(String fileUrl) onTapImage;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final thumbBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final noteSectionBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final status = prescription['status']?.toString().trim();
    final statusLabel = prescriptionStatusLabel(status);
    final statusColor = _prescriptionStatusColor(status);
    final stripeColor = queue == PrescriptionQueue.pending
        ? const Color(0xFFF59E0B)
        : _kRxAccent;
    final uploadDateLabel = formatPrescriptionSubmissionDate(
      prescription['created_at'] ?? readPrescriptionSubmissionRaw(prescription),
    );
    final pharmacistNote = _readPharmacistNote(prescription);
    final hasPharmacistNote = pharmacistNote.isNotEmpty;
    final imageUrl = prescription['file']?.toString();
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final noteTitleColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final noteBodyColor = isDark ? Colors.white70 : const Color(0xFF0F172A);

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
        child: InkWell(
          onTap: imageUrl != null ? () => onTapImage(imageUrl) : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: stripeColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: thumbBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 180,
                                        memCacheHeight: 180,
                                        placeholder: (_, __) => Icon(
                                          Icons.image_outlined,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF94A3B8),
                                        ),
                                        errorWidget: (_, __, ___) => Icon(
                                          Icons.medical_services_outlined,
                                          color: _kRxAccent,
                                        ),
                                      )
                                    : Icon(
                                        Icons.medical_services_outlined,
                                        color: _kRxAccent,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Prescription #${prescription['id']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: isDark
                                            ? Colors.white38
                                            : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          uploadDateLabel.isNotEmpty
                                              ? uploadDateLabel
                                              : 'No date',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.poppins(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: noteSectionBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.medical_information_outlined,
                                    size: 15,
                                    color: noteTitleColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pharmacist note',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: noteTitleColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hasPharmacistNote
                                    ? pharmacistNote
                                    : queue == PrescriptionQueue.pending
                                        ? 'Your upload is awaiting review.'
                                        : 'No pharmacist note provided.',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: hasPharmacistNote
                                      ? noteBodyColor
                                      : muted,
                                  height: 1.35,
                                  fontStyle: hasPharmacistNote
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

Color _prescriptionStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'approved':
    case 'served':
    case 'processed':
    case 'completed':
    case 'complete':
    case 'active':
    case 'fulfilled':
    case 'dispensed':
      return _kRxAccent;
    case 'rejected':
    case 'declined':
    case 'cancelled':
    case 'canceled':
      return const Color(0xFFDC2626);
    case 'pending':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF64748B);
  }
}

String _readPharmacistNote(Map<String, dynamic> prescription) {
  const possibleKeys = [
    'pharmacist_note',
    'pharmacist_notes',
    'pharmacist_comment',
    'review_note',
    'admin_note',
    'note',
    'notes',
    'comment',
  ];

  String? readFromMap(Map<String, dynamic> map) {
    for (final key in possibleKeys) {
      final value = map[key];
      if (value != null && value is! Map && value is! List) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final nested = readFromMap(value);
        if (nested != null && nested.isNotEmpty) return nested;
      } else if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            final nested = readFromMap(item);
            if (nested != null && nested.isNotEmpty) return nested;
          }
        }
      }
    }
    return null;
  }

  return readFromMap(prescription) ?? '';
}
