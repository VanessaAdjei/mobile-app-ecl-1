// pages/prescription_history.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/widgets/error_display.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/app_header_bar.dart';

const Color _kRxAccent = Color(0xFF0D7A4C);
const Color _kRxPageBg = Color(0xFFF6F8FA);
const Color _kRxPageMint = Color(0xFFEFFCF4);

class PrescriptionHistoryScreen extends StatefulWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  PrescriptionHistoryScreenState createState() =>
      PrescriptionHistoryScreenState();
}

class PrescriptionHistoryScreenState extends State<PrescriptionHistoryScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;

  String? _error;
  final ScrollController _scrollController = ScrollController();

  // Cache for prescription data
  static List<Map<String, dynamic>>? _cachedPrescriptions;
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  // Image loading optimization
  final Map<String, bool> _imageLoadingStates = {};
  final Map<String, String?> _imageErrors = {};

  @override
  void initState() {
    super.initState();

    setState(() {
      _isLoading = true;
    });
    _loadPrescriptions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrescriptions() async {
    debugPrint('🔍 Loading prescriptions...');
    // Check if we have valid cached data
    if (_cachedPrescriptions != null && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      final isCacheValid = timeSinceLastFetch < _cacheValidDuration;
      debugPrint(
          '🔍 Cache check: ${isCacheValid ? 'HIT' : 'MISS'} (age: ${timeSinceLastFetch.inMinutes}min)');

      if (isCacheValid) {
        setState(() {
          _prescriptions = _cachedPrescriptions!;
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

      final token = await AuthService.getToken();
      final authToken = token ?? 'guest-temp-token';

      // Show loading skeleton immediately
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Start API call
      final responseFuture = http.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.viewPrescription)),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      // Ensure minimum loading time for better UX (prevents flickering)
      final response = await Future.wait([
        responseFuture,
        Future.delayed(const Duration(milliseconds: 500)),
      ]).then((results) => results[0] as http.Response);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          final prescriptions = List<Map<String, dynamic>>.from(data['data']);

          debugPrint(
              '🔍 Fetched ${prescriptions.length} prescriptions from API');

          // Cache the data
          _cachedPrescriptions = prescriptions;
          _lastFetchTime = DateTime.now();

          if (mounted) {
            setState(() {
              _prescriptions = prescriptions;
              _isLoading = false;
            });

            // Preload images for better performance
            _preloadImages();
          }
        } else {
          throw Exception('No prescription data found');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unable to load prescriptions. Please try again.');
      } else {
        throw Exception(
            'Unable to connect to the server (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('🔍 Error fetching prescriptions: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPrescriptions() async {
    debugPrint('🔍 Refreshing prescriptions...');

    // Clear cache to force fresh data
    _cachedPrescriptions = null;
    _lastFetchTime = null;

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

    const scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : _kRxPageBg,
      appBar: const AppHeaderBar(
        title: 'Prescription History',
        subtitle: 'Uploads, status & pharmacist notes',
        showCart: false,
        background: AppHeaderBackground.accent,
      ),
      body: _rxPageBackdrop(
        isDark: isDark,
        child: _isLoading
            ? CustomScrollView(
                controller: _scrollController,
                physics: scrollPhysics,
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildLoadingSkeleton(isDark),
                  ),
                ],
              )
            : _error != null
                ? CustomScrollView(
                    controller: _scrollController,
                    physics: scrollPhysics,
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildErrorState(),
                      ),
                    ],
                  )
                : _prescriptions.isEmpty
                    ? CustomScrollView(
                        controller: _scrollController,
                        physics: scrollPhysics,
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(isDark),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        color: _kRxAccent,
                        onRefresh: _refreshPrescriptions,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: scrollPhysics,
                          slivers: _buildPrescriptionListSlivers(isDark),
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

  Widget _buildEmptyState(bool isDark) {
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: isDark ? 20 : 28,
                offset: const Offset(0, 12),
              ),
              if (!isDark)
                BoxShadow(
                  color: _kRxAccent.withValues(alpha: 0.07),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kRxAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 42,
                  color: _kRxAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No prescriptions yet',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When you upload a prescription, it will show up here.',
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

  List<Widget> _buildPrescriptionListSlivers(bool isDark) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                child: _buildPrescriptionItemAt(index, isDark),
              );
            },
            childCount: _prescriptions.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildPrescriptionItemAt(int index, bool isDark) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final thumbBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final noteSectionBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final prescription = _prescriptions[index];
    final statusRaw = (prescription['status'] ?? 'pending').toString();
    final status = statusRaw.trim();
    final statusLabel = status.isEmpty
        ? 'Pending'
        : (status.length == 1
            ? status.toUpperCase()
            : '${status[0].toUpperCase()}${status.substring(1)}');
    final uploadDate =
        (prescription['created_at'] ?? prescription['date'] ?? '').toString();
    final pharmacistNote = _extractPharmacistNote(prescription);
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
          onTap: imageUrl != null
              ? () => _showPrescriptionImage(imageUrl)
              : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _kRxAccent),
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
                                          uploadDate.isNotEmpty
                                              ? uploadDate.split('T').first
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
                                color: _getStatusColor(status)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.poppins(
                                  color: _getStatusColor(status),
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
                                    : 'No pharmacist note yet.',
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return _kRxAccent;
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _extractPharmacistNote(Map<String, dynamic> prescription) {
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
