// pages/prescription_history.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/services/auth_service.dart';
import 'app_back_button.dart';
import 'package:eclapp/widgets/error_display.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  Widget _buildLoadingSkeleton() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: Colors.green.shade700,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading Prescriptions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we fetch your prescription history...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    color: Colors.green.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Fetching your uploaded prescriptions',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrescriptionImage(String fileUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    constrained: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: CachedNetworkImage(
                      imageUrl: fileUrl,
                      fit: BoxFit.contain,
                      // Full resolution image loading
                      memCacheWidth: 1200,
                      memCacheHeight: 1200,
                      maxWidthDiskCache: 1600,
                      maxHeightDiskCache: 1600,
                      // Better placeholder
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                      ),
                      // Error handling
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.grey),
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
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Column(
        children: [
          // Modern page header
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
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
                            'Uploaded Prescriptions',
                            style: GoogleFonts.poppins(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'View your prescription history',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
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

          // Prescriptions content
          Expanded(
            child: _isLoading
                ? _buildLoadingSkeleton()
                : _error != null
                    ? _buildErrorState()
                    : _prescriptions.isEmpty
                        ? _buildEmptyState()
                        : _buildPrescriptionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return ErrorDisplay(
      title: 'Error Loading Prescriptions',
      message: _error ?? 'An error occurred while loading your prescriptions',
      onRetry: _refreshPrescriptions,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 42,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Prescriptions Yet',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You haven\'t uploaded any prescriptions yet.',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrescriptionsList() {
    return RefreshIndicator(
      onRefresh: _refreshPrescriptions,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        itemCount: _prescriptions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final prescription = _prescriptions[index];
          final status = (prescription['status'] ?? 'pending').toString();
          final uploadDate =
              (prescription['created_at'] ?? prescription['date'] ?? '')
                  .toString();
          final pharmacistNote = _extractPharmacistNote(prescription);
          final hasPharmacistNote = pharmacistNote.isNotEmpty;
          final imageUrl = prescription['file']?.toString();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: imageUrl != null ? () => _showPrescriptionImage(imageUrl) : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 180,
                                    memCacheHeight: 180,
                                    placeholder: (_, __) => const Icon(
                                      Icons.image_outlined,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.medical_services_outlined,
                                      color: Colors.green.shade700,
                                    ),
                                  )
                                : Icon(
                                    Icons.medical_services_outlined,
                                    color: Colors.green.shade700,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prescription #${prescription['id']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    uploadDate.isNotEmpty
                                        ? uploadDate.split('T').first
                                        : 'No date',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.medical_information_outlined,
                                size: 14,
                                color: Color(0xFF475569),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Pharmacist note',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
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
                            style: TextStyle(
                              fontSize: 12.5,
                              color: hasPharmacistNote
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
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
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
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
