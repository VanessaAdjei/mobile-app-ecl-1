// pages/pharmacists.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'app_back_button.dart';
import '../config/app_colors.dart';
import '../utils/app_error_utils.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/cart_icon_button.dart';
import 'pharmacists/pharmacists_bookings_sheet.dart';
import 'pharmacists/pharmacists_booking_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_tips_service.dart';
import '../models/health_tip.dart';
import '../services/auth_service.dart';
import 'signinpage.dart';
import '../services/booking_service.dart';

const Color _kPharmPageBg = Color(0xFFF5F7F6);
const Color _kPharmPageBgMint = Color(0xFFE3F2E6);

Color _pharmAccent(BuildContext context) =>
    context.appColors.isDark ? AppColors.primaryLight : AppColors.primary;

Widget _pharmPageBackdrop({
  required BuildContext context,
  required Widget child,
}) {
  final theme = context.appColors;
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: theme.isDark
            ? [
                const Color(0xFF14231C),
                theme.pageBg,
                theme.pageBg,
              ]
            : [
                _kPharmPageBgMint,
                _kPharmPageBg,
                _kPharmPageBg,
              ],
        stops: const [0.0, 0.38, 1.0],
      ),
    ),
    child: child,
  );
}

class PharmacistsPage extends StatefulWidget {
  const PharmacistsPage({super.key});

  @override
  State<PharmacistsPage> createState() => _PharmacistsPageState();
}

class _PharmacistsPageState extends State<PharmacistsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<dynamic>> _nameFieldKey =
      GlobalKey<FormFieldState<dynamic>>();
  final GlobalKey<FormFieldState<dynamic>> _phoneFieldKey =
      GlobalKey<FormFieldState<dynamic>>();
  final GlobalKey<FormFieldState<dynamic>> _emailFieldKey =
      GlobalKey<FormFieldState<dynamic>>();
  final GlobalKey<FormFieldState<dynamic>> _symptomsFieldKey =
      GlobalKey<FormFieldState<dynamic>>();

  String _selectedConsultationType = 'Video Call';
  String _selectedPreferredPlatform = 'Zoom';
  String _selectedGenderPreference = 'No Preference';
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Booking flow: user must pick availability before filling the form.
  int _bookingStep = 0; // 0 = date, 1 = time, 2 = form
  DateTime? _availabilityDate;
  TimeOfDay? _availabilityTime;
  List<DateTime> _availableDates = [];
  Set<String> _availableDateKeys = {};
  List<TimeOfDay> _availableTimes = [];

  final List<String> _consultationTypes = [
    'Video Call',
    'Audio Call',
    'Chat',
  ];
  final List<String> _preferredPlatforms = [
    'Zoom',
    'Google Meet',
    'WhatsApp',
    'Phone Call',
  ];
  final List<String> _genderPreferences = [
    'No Preference',
    'Male Pharmacist',
    'Female Pharmacist'
  ];

  List<Map<String, dynamic>> _bookings = [];
  List<HealthTip> _healthTips = [];
  bool _isLoadingHealthTips = false;
  bool _isUserLoggedIn = false;
  static List<HealthTip> _cachedHealthTips = [];
  static DateTime? _lastHealthTipsCacheTime;
  static const Duration _healthTipsCacheExpiration = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    // Load bookings regardless of login to support availability checks.
    _loadBookings();
    _checkLoginStatus();
    _loadHealthTips();
  }

  /// Upcoming and other non-overdue bookings only (overdue live on My Appointments).
  List<Map<String, dynamic>> get _pharmacistPageBookings =>
      activeBookingsForPharmacistsPage(_bookings);

  Future<void> _loadBookings() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      final result = await BookingService.getHistory();
      if (result['success'] == true && result['data'] is List) {
        final list = result['data'] as List<dynamic>;
        final items = list
            .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
            .toList();
        if (mounted) {
          setState(() => _bookings = items);
        }
        await _saveBookings();
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final bookingsJson = prefs.getStringList('pharmacist_bookings') ?? [];
    if (mounted) {
      setState(() {
        _bookings = bookingsJson
            .map((e) => Map<String, dynamic>.from(_decodeJson(e)))
            .toList();
      });
    }
  }

  Future<void> _saveBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final bookingsJson = _bookings.map((e) => _encodeJson(e)).toList();
    await prefs.setStringList('pharmacist_bookings', bookingsJson);
  }

  String _encodeJson(Map<String, dynamic> map) => jsonEncode(map);
  Map<String, dynamic> _decodeJson(String s) => jsonDecode(s);

  Future<void> _loadHealthTips() async {
    debugPrint('PharmacistsPage: _loadHealthTips called');
    setState(() {
      _isLoadingHealthTips = true;
    });

    final backgroundTips = HealthTipsService.getCurrentTips(limit: 4);
    if (backgroundTips.isNotEmpty) {
      setState(() {
        _healthTips = backgroundTips;
        _isLoadingHealthTips = false;
      });
      return;
    }

    if (_isLocalCacheValid()) {
      setState(() {
        _healthTips = _cachedHealthTips;
        _isLoadingHealthTips = false;
      });
      debugPrint('PharmacistsPage: Using local cached health tips');
      return;
    }
    _showInstantFallbackTips();

    _loadFreshHealthTipsInBackground();
  }

  Future<void> _refreshHealthTips() async {
    // show feedback right away
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
            SizedBox(width: 12),
            Text('Refreshing health insights...'),
          ],
        ),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );

    _cachedHealthTips.clear();
    _lastHealthTipsCacheTime = null;

    await _loadFreshHealthTipsInBackground();
  }

  bool _isLocalCacheValid() {
    if (_cachedHealthTips.isEmpty) return false;
    if (_lastHealthTipsCacheTime == null) return false;

    final timeSinceLastCache =
        DateTime.now().difference(_lastHealthTipsCacheTime!);
    return timeSinceLastCache < _healthTipsCacheExpiration;
  }

  void _showInstantFallbackTips() {
    debugPrint('PharmacistsPage: Showing instant fallback tips');
    final instantTips = [
      HealthTip(
        title: 'Stay Hydrated',
        content:
            'Drink at least 8 glasses of water daily to maintain good health and energy levels.',
        url: '',
        category: 'Wellness',
        imageUrl: null,
        summary:
            'Proper hydration is essential for overall health and well-being.',
      ),
      HealthTip(
        title: 'Regular Exercise',
        content:
            'Aim for at least 30 minutes of moderate physical activity most days of the week.',
        url: '',
        category: 'Exercise',
        imageUrl: null,
        summary:
            'Regular exercise helps maintain a healthy weight and reduces disease risk.',
      ),
      HealthTip(
        title: 'Balanced Nutrition',
        content:
            'Include a variety of fruits, vegetables, whole grains, and lean proteins in your diet.',
        url: '',
        category: 'Nutrition',
        imageUrl: null,
        summary:
            'A balanced diet provides essential nutrients for optimal health.',
      ),
      HealthTip(
        title: 'Mental Health Care',
        content:
            'Practice stress management techniques like meditation, deep breathing, or talking to friends.',
        url: '',
        category: 'Mental Health',
        imageUrl: null,
        summary:
            'Taking care of your mental health is as important as physical health.',
      ),
    ];

    setState(() {
      _healthTips = instantTips;
      _isLoadingHealthTips = false;
    });
    debugPrint(
        'PharmacistsPage: Fallback tips set, count: ${_healthTips.length}');
  }

  Future<void> _loadFreshHealthTipsInBackground() async {
    try {
      final backgroundTips = HealthTipsService.getCurrentTips(limit: 4);
      if (backgroundTips.isNotEmpty) {
        setState(() {
          _healthTips = backgroundTips;
          _isLoadingHealthTips = false;
        });
        return;
      }

      final tips = await HealthTipsService.fetchHealthTips(limit: 4)
          .timeout(Duration(seconds: 6));

      if (mounted && tips.isNotEmpty) {
        // save the fresh tips locally
        _cachedHealthTips = tips;
        _lastHealthTipsCacheTime = DateTime.now();

        setState(() {
          _healthTips = tips;
          _isLoadingHealthTips = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fresh health tips: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      setState(() {
        _isUserLoggedIn = isLoggedIn;
      });

      if (isLoggedIn) {
        await _loadBookings();
        await _prefillUserData();
      }
    } catch (e) {
      setState(() {
        _isUserLoggedIn = false;
      });
      debugPrint('Error checking login status: $e');
    }
  }

  void _showLoginRequiredDialog() {
    final theme = context.appColors;

    showDialog(
      context: context,
      barrierColor: theme.isDark
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.sheetBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: theme.isDark
                        ? [
                            AppColors.primary.withValues(alpha: 0.85),
                            AppColors.primaryDark,
                          ]
                        : [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.login,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Login Required',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to be logged in to book a consultation with our pharmacists.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.muted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.muted,
                        side: BorderSide(color: theme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _navigateToLogin();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignInScreen(
          onSuccess: () async {
            if (mounted) {
              await _checkLoginStatus();

              if (!context.mounted) return;

              // show success message
              AppErrorUtils.showSnack(
                  context, 'Welcome back! You can now book consultations.',
                  isError: false);
            }
          },
        ),
      ),
    );

    // Check if we returned from login and refresh status
    if (mounted) {
      await _checkLoginStatus();
    }
  }

  Widget _buildLoginPromptCard({
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 16),
    bool compact = false,
  }) {
    final theme = context.appColors;
    final pad = compact ? 8.0 : 14.0;
    final iconBox = compact ? 30.0 : 40.0;
    final iconRadius = compact ? 8.0 : 12.0;
    final titleSize = compact ? 11.0 : 13.0;
    final bodySize = compact ? 10.0 : 11.0;
    final cardRadius = compact ? 12.0 : 18.0;

    return Container(
      margin: margin,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: theme.isDark
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.primary.withOpacity(0.28),
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.isDark ? 0.24 : 0.04,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: theme.isDark
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(iconRadius),
            ),
            child: Icon(Icons.lock_outline_rounded,
                color: _pharmAccent(context), size: compact ? 16 : 20),
          ),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  compact
                      ? 'Sign in to sync bookings'
                      : 'Sign in to manage bookings',
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                  ),
                ),
                if (!compact)
                  Text(
                    'Use your Ernest account to book and track consultations.',
                    style: GoogleFonts.poppins(
                      fontSize: bodySize,
                      color: theme.muted,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
              onTap: _navigateToLogin,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 14,
                  vertical: compact ? 6 : 10,
                ),
                child: Text(
                  'Login',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prefillUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (userData != null) {
        // Controllers update the fields directly; no widget rebuild required.
        final name = userData['name']?.toString() ?? '';
        final phone = userData['phone']?.toString() ?? '';
        final email = userData['email']?.toString() ?? '';

        // Only prefill empty fields so we don't overwrite user edits.
        if (_nameController.text.trim().isEmpty && name.trim().isNotEmpty) {
          _nameController.text = name;
        }
        if (_phoneController.text.trim().isEmpty && phone.trim().isNotEmpty) {
          _phoneController.text = phone;
        }
        if (_emailController.text.trim().isEmpty && email.trim().isNotEmpty) {
          _emailController.text = email;
        }
      }
    } catch (e) {
      debugPrint('Error prefilling user data: $e');
    }
  }

  Future<void> _clearBookings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pharmacist_bookings');
    setState(() {
      _bookings.clear();
    });
  }

  /// Cancel a booking via API (when it has id) and remove from list.
  /// Returns true if cancel succeeded (so caller can close sheet).
  Future<bool> _cancelBooking(Map<String, dynamic> booking) async {
    final id = booking['id'];
    if (id == null) {
      setState(() => _bookings.remove(booking));
      await _saveBookings();
      return true;
    }
    final result = await BookingService.cancel(id.toString());
    if (!context.mounted) return false;
    if (result['success'] == true) {
      setState(() =>
          _bookings.removeWhere((e) => e['id'] == id || identical(e, booking)));
      await _saveBookings();
      AppErrorUtils.showSnack(context, 'Booking cancelled', isError: false);
      return true;
    } else {
      AppErrorUtils.showSnack(
          context, result['message']?.toString() ?? 'Failed to cancel booking',
          isError: true);
      return false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  void _showHealthTipDetails(HealthTip tip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = sheetContext.appColors;

        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
          decoration: BoxDecoration(
            color: theme.sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.36 : 0.15,
                ),
                blurRadius: 25,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // drag handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.handleBar,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // header section
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.health_and_safety,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health Insight',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            tip.category,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // health tip title
                      Text(
                        tip.title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.ink,
                        ),
                      ),
                      SizedBox(height: 16),

                      // show image if we have one
                      if (tip.imageUrl != null && tip.imageUrl!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          height: 200,
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              tip.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: theme.fieldBg,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: theme.muted,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      // health tip content
                      Text(
                        tip.content,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: theme.ink.withValues(alpha: 0.88),
                          height: 1.6,
                        ),
                      ),

                      if (tip.summary != null &&
                          tip.summary != tip.content) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.isDark
                                  ? AppColors.primary.withValues(alpha: 0.28)
                                  : Colors.green.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Summary',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.isDark
                                      ? AppColors.primaryLight
                                      : Colors.green.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tip.summary!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: theme.isDark
                                      ? theme.ink.withValues(alpha: 0.88)
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 24),

                      // buttons to read more or share
                      if (tip.url.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[500]!, Colors.green[600]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _launchHealthTipUrl(tip.url),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.open_in_new,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Learn More',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchHealthTipUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AppErrorUtils.showSnack(context, 'Could not open the link',
            isError: true);
      }
    } catch (e) {
      AppErrorUtils.showSnack(context, 'Error opening link: $e', isError: true);
    }
  }

  void _showBookingForm() async {
    await _prepareAvailabilityForBooking();
    await _prefillUserData();
    final loadingSessionsHolder = [false];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = context.appColors;
            final stepTitles = ['Pick a date', 'Pick a time', 'Your details'];
            final stepHints = [
              'Choose an open day in the calendar',
              'Select a slot that works for you',
              'Tell us how to reach you and what you need',
            ];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: theme.isDark
                        ? [
                            const Color(0xFF14231C),
                            theme.pageBg,
                          ]
                        : [
                            const Color(0xFFF2FBF6),
                            const Color(0xFFE8F2EC),
                          ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 24, color: Colors.white),
                                    onPressed: () {
                                      if (_bookingStep > 0) {
                                        setDialogState(() {
                                          _bookingStep -= 1;
                                        });
                                        return;
                                      }
                                      Navigator.pop(context);
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Book appointment',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white
                                                .withValues(alpha: 0.88),
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                        Text(
                                          stepTitles[_bookingStep],
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                stepHints[_bookingStep],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildBookingFlowStepDots(_bookingStep),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.sheetBg,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SafeArea(
                          top: false,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _bookingStep == 0
                                ? _buildSelectDateStep(
                                    key: const ValueKey('step0'),
                                    setDialogState: setDialogState,
                                    loadingSessionsHolder:
                                        loadingSessionsHolder,
                                  )
                                : _bookingStep == 1
                                    ? _buildSelectTimeStep(
                                        key: const ValueKey('step1'),
                                        setDialogState: setDialogState,
                                      )
                                    : _buildBookingFormStep(
                                        key: const ValueKey('step2'),
                                        setDialogState: setDialogState,
                                      ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Three-step progress for the booking dialog header.
  Widget _buildBookingFlowStepDots(int activeIndex) {
    const labels = ['Date', 'Time', 'Details'];

    Widget connector(int afterIndex) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 13, left: 4, right: 4),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: activeIndex > afterIndex
                  ? Colors.white.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    Widget node(int i) {
      final done = i < activeIndex;
      final current = i == activeIndex;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  current ? Colors.white : Colors.white.withValues(alpha: 0.2),
              border: current
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 16, color: AppColors.accent)
                : Text(
                    '${i + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: current ? AppColors.accent : Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            labels[i],
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: current ? 1 : 0.72),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        node(0),
        connector(0),
        node(1),
        connector(1),
        node(2),
      ],
    );
  }

  Future<void> _prepareAvailabilityForBooking() async {
    if (!mounted) return;
    await _loadBookings();
    setState(() {
      _bookingStep = 0;
      _availabilityDate = null;
      _availabilityTime = null;
      _availableTimes = [];
    });
    _refreshAvailableDates();
  }

  void _refreshAvailableDates({StateSetter? dialogSetState}) {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final end = start.add(const Duration(days: 30));

    final dates = <DateTime>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final times = _computeAvailableTimesForDate(d);
      if (times.isNotEmpty) dates.add(d);
    }

    if (!mounted) return;
    final update = dialogSetState ?? setState;
    update(() {
      _availableDates = dates;
      _availableDateKeys = dates.map(_dateKey).toSet();

      // CalendarDatePicker highlights an initialDate even when the user
      // hasn't interacted yet. To keep the "Next" button usable, we
      // auto-select the first available date (or clear if none exist).
      if (dates.isEmpty) {
        _availabilityDate = null;
      } else {
        final current = _availabilityDate;
        if (current == null ||
            !_availableDateKeys.contains(_dateKey(current))) {
          _availabilityDate = dates.first;
        }
      }
    });
  }

  List<TimeOfDay> _computeAvailableTimesForDate(DateTime date) {
    final slots = _generateStandardTimeSlots();
    final booked = <String>{};
    for (final b in _pharmacistPageBookings) {
      final dt = _parseBookingDateTime(b);
      if (dt == null) continue;
      if (_isSameDay(dt, date)) {
        booked.add(_timeKey(TimeOfDay(hour: dt.hour, minute: dt.minute)));
      }
    }

    final now = DateTime.now();
    final isToday = _isSameDay(date, now);

    return slots.where((t) {
      if (booked.contains(_timeKey(t))) return false;
      if (isToday) {
        final dt = DateTime(date.year, date.month, date.day, t.hour, t.minute);
        if (!dt.isAfter(now.add(const Duration(minutes: 15)))) return false;
      }
      return true;
    }).toList();
  }

  List<TimeOfDay> _generateStandardTimeSlots() {
    // 30-minute slots from 09:00 to 17:00 (inclusive)
    final slots = <TimeOfDay>[];
    for (int hour = 9; hour <= 17; hour++) {
      slots.add(TimeOfDay(hour: hour, minute: 0));
      if (hour != 17) {
        slots.add(TimeOfDay(hour: hour, minute: 30));
      }
    }
    return slots;
  }

  DateTime? _parseBookingDateTime(Map<String, dynamic> b) {
    try {
      // API history format: session_date "2026-01-27", start_time "09:00:00"
      final sessionDate = b['session_date']?.toString();
      final startTime = b['start_time']?.toString();
      if (sessionDate != null &&
          sessionDate.isNotEmpty &&
          startTime != null &&
          startTime.isNotEmpty) {
        final dateParts = sessionDate.split('-');
        final timeParts = startTime.split(':');
        if (dateParts.length >= 3 && timeParts.length >= 2) {
          final year = int.tryParse(dateParts[0]) ?? 2000;
          final month = int.tryParse(dateParts[1]) ?? 1;
          final day = int.tryParse(dateParts[2]) ?? 1;
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          return DateTime(year, month, day, hour, minute);
        }
      }
      // Local format: date "d/m/y", time "2:30 PM" or "14:30"
      final parts = (b['date'] ?? '').toString().split('/');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 2000;
      final time = _parseTimeOfDay((b['time'] ?? '').toString());
      if (time == null) return null;
      return DateTime(year, month, day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final ampm = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(s);
    if (ampm != null) {
      int hour = int.tryParse(ampm.group(1)!) ?? 0;
      final minute = int.tryParse(ampm.group(2)!) ?? 0;
      final suffix = ampm.group(3)!.toUpperCase();
      if (suffix == 'PM' && hour < 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final hm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (hm != null) {
      final hour = int.tryParse(hm.group(1)!) ?? 0;
      final minute = int.tryParse(hm.group(2)!) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _timeKey(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _buildSelectDateStep({
    Key? key,
    required StateSetter setDialogState,
    List<bool>? loadingSessionsHolder,
  }) {
    final now = DateTime.now();
    final firstDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final lastDate = firstDate.add(const Duration(days: 30));
    final initialDate = _availabilityDate ??
        (_availableDates.isNotEmpty ? _availableDates.first : firstDate);
    final isLoading = loadingSessionsHolder != null &&
        loadingSessionsHolder.isNotEmpty &&
        loadingSessionsHolder[0];
    final theme = context.appColors;

    return Container(
      key: key,
      color: theme.sheetBg,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.isDark
                    ? AppColors.primary.withValues(alpha: 0.28)
                    : const Color(0xFFC8E6C9),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: _pharmAccent(context), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open days only',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                        ),
                      ),
                      Text(
                        'Greyed-out dates are fully booked or closed.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.fieldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.isDark ? 0.2 : 0.04,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          onSurface: theme.ink,
                          onSurfaceVariant: theme.muted,
                        ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    selectableDayPredicate: (date) {
                      return _availableDateKeys.contains(_dateKey(date));
                    },
                    onDateChanged: (date) {
                      setDialogState(() {
                        _availabilityDate = date;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_availableDates.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No open days in the next 30 days. Try again later or contact support.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.muted,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _availabilityDate == null || isLoading
                  ? null
                  : () async {
                      final date = _availabilityDate!;
                      final dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      setDialogState(() {
                        if (loadingSessionsHolder != null &&
                            loadingSessionsHolder.isNotEmpty) {
                          loadingSessionsHolder[0] = true;
                        }
                      });
                      final result =
                          await BookingService.getAvailableSessions(dateStr);
                      if (!mounted) return;
                      List<TimeOfDay> times = [];
                      if (result['success'] == true && result['data'] is List) {
                        final sessions = result['data'] as List<dynamic>;
                        for (final s in sessions) {
                          if (s is! Map) continue;
                          if (s['available'] != true) continue;
                          final start = s['start']?.toString();
                          if (start == null || start.isEmpty) continue;
                          final parts = start.split(':');
                          final hour = parts.isNotEmpty
                              ? int.tryParse(parts[0]) ?? 0
                              : 0;
                          final minute = parts.length > 1
                              ? int.tryParse(parts[1]) ?? 0
                              : 0;
                          times.add(TimeOfDay(hour: hour, minute: minute));
                        }
                      }
                      if (times.isEmpty) {
                        times =
                            _computeAvailableTimesForDate(_availabilityDate!);
                      }
                      setDialogState(() {
                        _availableTimes = times;
                        _availabilityTime = null;
                        _bookingStep = 1;
                        if (loadingSessionsHolder != null &&
                            loadingSessionsHolder.isNotEmpty) {
                          loadingSessionsHolder[0] = false;
                        }
                      });
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'See available times',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectTimeStep({Key? key, required StateSetter setDialogState}) {
    final theme = context.appColors;
    final date = _availabilityDate;
    return Container(
      key: key,
      color: theme.sheetBg,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.isDark
                      ? [
                          AppColors.primary.withValues(alpha: 0.16),
                          theme.fieldBg,
                        ]
                      : [
                          AppColors.primary.withValues(alpha: 0.12),
                          const Color(0xFFE8F5E9),
                        ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.isDark
                      ? AppColors.primary.withValues(alpha: 0.28)
                      : const Color(0xFFC8E6C9),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded,
                      color: _pharmAccent(context), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMMM d, y').format(date),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (date != null) const SizedBox(height: 16),
          Text(
            'Choose a time slot',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.muted,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _availableTimes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No times left for this day. Go back and pick another date.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: theme.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.35,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _availableTimes.length,
                    itemBuilder: (context, index) {
                      final t = _availableTimes[index];
                      final isSelected = _availabilityTime != null &&
                          _timeKey(t) == _timeKey(_availabilityTime!);
                      final unselectedBg = theme.isDark
                          ? const Color(0xFF2A3A4F)
                          : const Color(0xFFF0FAF4);
                      final unselectedBorder = theme.isDark
                          ? AppColors.primaryLight.withValues(alpha: 0.45)
                          : AppColors.primary.withValues(alpha: 0.32);
                      final unselectedText =
                          theme.isDark ? Colors.white : const Color(0xFF1F2937);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => _availabilityTime = t),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primaryDark,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : unselectedBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : unselectedBorder,
                                width: isSelected ? 1.5 : 1.25,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: theme.isDark ? 0.22 : 0.05,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Text(
                              t.format(context),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    isSelected ? Colors.white : unselectedText,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _availabilityDate == null || _availabilityTime == null
                  ? null
                  : () {
                      setDialogState(() {
                        _selectedDate = _availabilityDate!;
                        _selectedTime = _availabilityTime!;
                        _bookingStep = 2;
                      });
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    theme.isDark ? Colors.white24 : Colors.grey.shade300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to details',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_note_rounded, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingFormStep(
      {Key? key, required StateSetter setDialogState}) {
    final theme = context.appColors;

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.isDark
                      ? AppColors.primary.withValues(alpha: 0.28)
                      : const Color(0xFFC8E6C9),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: _pharmAccent(context), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your slot is reserved below. Complete the form and submit to confirm.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSimpleFormSection(
              'Consultation',
              Icons.video_call_outlined,
              [
                _buildSimpleDropdownField(
                  'Mode of Consultation',
                  _selectedConsultationType,
                  _consultationTypes,
                  (value) =>
                      setDialogState(() => _selectedConsultationType = value!),
                ),
                const SizedBox(height: 12),
                _buildSimpleDropdownField(
                  'Preferred Platform',
                  _selectedPreferredPlatform,
                  _preferredPlatforms,
                  (value) =>
                      setDialogState(() => _selectedPreferredPlatform = value!),
                ),
                const SizedBox(height: 12),
                _buildSimpleDropdownField(
                  'Gender Preference',
                  _selectedGenderPreference,
                  _genderPreferences,
                  (value) =>
                      setDialogState(() => _selectedGenderPreference = value!),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSimpleFormSection(
              'Your details',
              Icons.person_outline_rounded,
              [
                _buildSimpleTextField(
                  'Full Name',
                  _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  fieldKey: _nameFieldKey,
                ),
                const SizedBox(height: 12),
                _buildSimpleTextField(
                  'Phone Number',
                  _phoneController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  fieldKey: _phoneFieldKey,
                ),
                const SizedBox(height: 12),
                _buildSimpleTextField(
                  'Email Address',
                  _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                  fieldKey: _emailFieldKey,
                  autofillHints: const [AutofillHints.email],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSimpleFormSection(
              'Reason for Appointment',
              Icons.healing_outlined,
              [
                _buildSimpleTextField(
                  'Symptoms or concerns',
                  _symptomsController,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  fieldKey: _symptomsFieldKey,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSimpleFormSection(
              'Schedule',
              Icons.schedule_rounded,
              [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                    color: theme.fieldBg,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded,
                          color: _pharmAccent(context), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMM d, y').format(_selectedDate)} · ${_selectedTime.format(context)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.ink,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _bookingStep = 0;
                            _availabilityDate = null;
                            _availabilityTime = null;
                            _availableTimes = [];
                          });
                          _refreshAvailableDates(
                              dialogSetState: setDialogState);
                        },
                        child: Text(
                          'Change',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildSimpleSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Simplified form section
  Widget _buildSimpleFormSection(
      String title, IconData sectionIcon, List<Widget> children) {
    final theme = context.appColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.isDark ? theme.fieldBg : theme.sheetBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.isDark ? 0.18 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sectionIcon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // Simplified dropdown field
  Widget _buildSimpleDropdownField(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    final theme = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
            color: theme.fieldBg,
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.ink,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: _pharmAccent(context), size: 22),
            dropdownColor: theme.sheetBg,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: theme.ink,
            ),
          ),
        ),
      ],
    );
  }

  // Simplified text field
  Widget _buildSimpleTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    int maxLines = 1,
    GlobalKey<FormFieldState<dynamic>>? fieldKey,
    List<String>? autofillHints,
  }) {
    final theme = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          autofillHints: autofillHints,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.fieldBg,
            hintText: maxLines > 1 ? null : 'Enter $label',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.inputHint,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: theme.inputText,
          ),
        ),
      ],
    );
  }

  // Simplified submit button
  Widget _buildSimpleSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _submitBookingWithValidation,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 22),
            const SizedBox(width: 10),
            Text(
              'Submit booking request',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitBookingWithValidation() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      _showLoginRequiredDialog();
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (_nameController.text.isEmpty) {
        _scrollToField(_nameFieldKey);
      } else if (_phoneController.text.isEmpty) {
        _scrollToField(_phoneFieldKey);
      } else if (_emailController.text.isEmpty) {
        _scrollToField(_emailFieldKey);
      } else if (_symptomsController.text.isEmpty) {
        _scrollToField(_symptomsFieldKey);
      }
      AppErrorUtils.showSnack(context, 'Please complete all required fields.',
          isError: true, duration: Duration(seconds: 4));
      return;
    }
    final sessionDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final startTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final endHour = _selectedTime.hour + 2;
    final endMinute = _selectedTime.minute;
    final endTime =
        '${(endHour % 24).toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    final typeValue =
        _selectedConsultationType.toLowerCase().replaceAll(' ', '');
    final apiBody = {
      'session_date': sessionDate,
      'start_time': startTime,
      'end_time': endTime,
      'full_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'platform': _selectedPreferredPlatform,
      'type': typeValue,
      'reason': _symptomsController.text.trim(),
    };
    final localBooking = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'symptoms': _symptomsController.text,
      'consultationType': _selectedConsultationType,
      'preferredPlatform': _selectedPreferredPlatform,
      'genderPreference': _selectedGenderPreference,
      'date':
          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
      'time': _selectedTime.format(context),
    };
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(),
    );
    try {
      final result = await BookingService.book(apiBody);
      if (!mounted) return;
      Navigator.pop(context);
      if (result['success'] == true) {
        final bookingData = result['booking'];
        if (bookingData is Map<String, dynamic>) {
          setState(() => _bookings.insert(0, bookingData));
        } else {
          setState(() => _bookings.insert(0, localBooking));
        }
        await _saveBookings();
        _showSuccessDialog();
      } else {
        AppErrorUtils.showSnack(
            context, result['message']?.toString() ?? 'Booking failed',
            isError: true, duration: Duration(seconds: 4));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _bookings.insert(0, localBooking));
      await _saveBookings();
      _showSuccessDialog();
    }
  }

  void _scrollToField(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  Widget _buildLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Booking Your Consultation...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait while we process your request',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Booking Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your consultation has been booked successfully. We\'ll contact you soon to confirm the details.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[500]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final navigator =
                          Navigator.of(context, rootNavigator: true);
                      // Close booking overlays and return to the page underneath.
                      navigator.popUntil((route) => route is! PopupRoute);
                      // Clear form
                      _nameController.clear();
                      _phoneController.clear();
                      _emailController.clear();
                      _symptomsController.clear();
                      setState(() {
                        _selectedDate = DateTime.now().add(Duration(days: 1));
                        _selectedTime = TimeOfDay.now();
                      });
                    },
                    child: Center(
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Unified “your bookings” area under the app bar (next visit + actions).
  Widget _buildTopBookingsStrip() {
    final visible = _pharmacistPageBookings;
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = context.appColors;

    void openAllBookings() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BookingsListSheet(
          bookings: visible,
          onClear: _clearBookings,
          onCancelBooking: _cancelBooking,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.isDark ? theme.sheetBg : const Color(0xFFF0FAF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.isDark
                ? theme.border
                : AppColors.primary.withValues(alpha: 0.22),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visible.length == 1
                            ? 'Next booking'
                            : 'Bookings (${visible.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (visible.length > 1)
                      TextButton(
                        onPressed: openAllBookings,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'All',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: _clearBookings,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: _isUserLoggedIn
                    ? _buildSlimBookingCard(
                        visible.first,
                        margin: EdgeInsets.zero,
                        compact: true,
                        omitDetailLine: true,
                      )
                    : _buildLoginPromptCard(
                        margin: EdgeInsets.zero,
                        compact: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPharmacistPageHeader() {
    final top = MediaQuery.paddingOf(context).top;
    return ClipPath(
      clipper: _PharmacistWaveClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(10, top + 6, 14, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF062A12),
              Color(0xFF0D3D18),
              AppColors.accent,
              Color(0xFF2E7D32),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackButtonUtils.simple(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pharmacist care',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Licensed guidance, private consultations',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              child: CartIconButton(
                iconColor: Colors.white,
                iconSize: 20,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBookingsSheet() {
    final visible = _pharmacistPageBookings;
    if (visible.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingsListSheet(
        bookings: visible,
        onClear: _clearBookings,
        onCancelBooking: _cancelBooking,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBookings = _pharmacistPageBookings.isNotEmpty;
    final pageBg = context.appColors.pageBg;

    return Scaffold(
      backgroundColor: pageBg,
      body: _pharmPageBackdrop(
        context: context,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildPharmacistPageHeader()),
            if (hasBookings)
              SliverToBoxAdapter(child: _buildTopBookingsStrip()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, hasBookings ? 12 : 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeroSection(),
                  const SizedBox(height: 16),
                  _buildRedesignedHealthTipsSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final theme = context.appColors;
    final hasBookings = _pharmacistPageBookings.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.isDark
              ? theme.border
              : AppColors.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.isDark
                ? Colors.black.withValues(alpha: 0.28)
                : AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2.25,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/banner2.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryDark.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    'Expert medication guidance',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PharmacistActionTile(
                        icon: Icons.calendar_month_rounded,
                        label: 'Book appointment',
                        subtitle: 'Video, audio, or chat',
                        filled: true,
                        onTap: _showBookingForm,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PharmacistActionTile(
                        icon: Icons.event_note_rounded,
                        label: 'My bookings',
                        subtitle: hasBookings
                            ? '${_pharmacistPageBookings.length} upcoming'
                            : 'None yet',
                        filled: false,
                        onTap: hasBookings
                            ? _openBookingsSheet
                            : () {
                                AppErrorUtils.showSnack(
                                  context,
                                  'Book a session to see it here.',
                                );
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.isDark
                          ? [
                              AppColors.primary.withValues(alpha: 0.14),
                              theme.fieldBg,
                            ]
                          : [
                              const Color(0xFFE8F5E9),
                              const Color(0xFFF4FBF6),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.isDark
                          ? AppColors.primary.withValues(alpha: 0.24)
                          : AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_rounded,
                          size: 18,
                          color: theme.isDark
                              ? AppColors.primaryLight
                              : AppColors.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Licensed pharmacists · Confidential · Flexible times',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: theme.muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color primary, Color accent}) _categoryVisualsForTip(
      HealthTip tip) {
    IconData icon;
    Color primaryColor;
    Color accentColor;

    switch (tip.category.toLowerCase()) {
      case 'nutrition':
      case 'diet':
        icon = Icons.restaurant_rounded;
        primaryColor = Colors.orange.shade600;
        accentColor = Colors.orange.shade50;
        break;
      case 'exercise':
      case 'physical activity':
        icon = Icons.fitness_center_rounded;
        primaryColor = Colors.blue.shade600;
        accentColor = Colors.blue.shade50;
        break;
      case 'mental health':
        icon = Icons.psychology_rounded;
        primaryColor = Colors.purple.shade600;
        accentColor = Colors.purple.shade50;
        break;
      case 'prevention':
        icon = Icons.shield_rounded;
        primaryColor = Colors.green.shade600;
        accentColor = Colors.green.shade50;
        break;
      case 'wellness':
        icon = Icons.health_and_safety_rounded;
        primaryColor = Colors.teal.shade600;
        accentColor = Colors.teal.shade50;
        break;
      case 'heart health':
      case 'cardiovascular':
        icon = Icons.favorite_rounded;
        primaryColor = Colors.red.shade600;
        accentColor = Colors.red.shade50;
        break;
      case 'diabetes':
        icon = Icons.monitor_heart_rounded;
        primaryColor = Colors.orange.shade600;
        accentColor = Colors.orange.shade50;
        break;
      case 'pregnancy':
      case 'women\'s health':
        icon = Icons.pregnant_woman_rounded;
        primaryColor = Colors.pink.shade600;
        accentColor = Colors.pink.shade50;
        break;
      default:
        icon = Icons.health_and_safety_rounded;
        primaryColor = Colors.green.shade600;
        accentColor = Colors.green.shade50;
    }
    return (icon: icon, primary: primaryColor, accent: accentColor);
  }

  /// MyHealthfinder sometimes returns site-relative image paths.
  String? _resolvedHealthTipImageUrl(HealthTip tip) {
    final raw = tip.imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://health.gov$raw';
    return raw;
  }

  /// One-line preview for compact tips list.
  String _compactTipPreview(HealthTip tip) {
    final raw = tip.summary?.trim().isNotEmpty == true
        ? tip.summary!.trim()
        : tip.content.trim();
    if (raw.length <= 80) return raw;
    return '${raw.substring(0, 80).trim()}…';
  }

  Widget _buildCompactHealthTipRow(HealthTip tip) {
    final theme = context.appColors;
    final v = _categoryVisualsForTip(tip);
    final badgeBg = theme.isDark ? v.primary.withValues(alpha: 0.18) : v.accent;
    final preview = _compactTipPreview(tip);
    final String? resolvedImageUrl = _resolvedHealthTipImageUrl(tip);
    final bool hasImage =
        resolvedImageUrl != null && resolvedImageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showHealthTipDetails(tip),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.border),
                      color: badgeBg,
                    ),
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: resolvedImageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 180),
                            placeholder: (_, __) => Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: v.primary.withOpacity(0.75),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              v.icon,
                              color: v.primary,
                              size: 26,
                            ),
                          )
                        : Center(
                            child: Icon(
                              v.icon,
                              color: v.primary,
                              size: 26,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tip.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: v.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: theme.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.muted.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHealthTipsList() {
    final theme = context.appColors;

    if (_isLoadingHealthTips) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.sheetBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _pharmAccent(context),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading tips…',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: theme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_healthTips.isEmpty) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.sheetBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Center(
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 22, color: _pharmAccent(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No tips yet. Pull refresh above.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.muted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tips = _healthTips.take(4).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tips.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.border,
              ),
            _buildCompactHealthTipRow(tips[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildSlimBookingCard(
    Map<String, dynamic> b, {
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 16),
    bool compact = false,
    bool omitDetailLine = false,
  }) {
    final theme = context.appColors;
    final isUpcoming = isBookingUpcoming(b);
    final isPastDue = isBookingPastDue(b);
    final radius = compact ? 12.0 : 20.0;
    final barW = compact ? 2.5 : 4.0;
    final innerPad = compact
        ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
        : const EdgeInsets.fromLTRB(12, 11, 12, 10);
    final dateFont = compact ? 11.0 : 13.0;
    final nameFont = compact ? 10.0 : 12.0;
    final metaFont = compact ? 9.5 : 11.0;
    final gapMid = compact ? 3.0 : 8.0;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isUpcoming
              ? (theme.isDark
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.primary.withOpacity(0.35))
              : isPastDue
                  ? (theme.isDark
                      ? Colors.amber.withValues(alpha: 0.35)
                      : Colors.amber.shade200)
                  : theme.border,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.isDark ? 0.24 : 0.05,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: barW,
                decoration: BoxDecoration(
                  color: isUpcoming
                      ? AppColors.primary
                      : isPastDue
                          ? Colors.amber.shade700
                          : Colors.grey.shade400,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: innerPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_rounded,
                              color: isPastDue
                                  ? Colors.amber.shade800
                                  : AppColors.primary,
                              size: compact ? 13 : 16),
                          SizedBox(width: compact ? 3 : 6),
                          Expanded(
                            child: Text(
                              '${bookingDisplayDate(b)} · ${bookingDisplayTime(b)}',
                              style: GoogleFonts.poppins(
                                fontSize: dateFont,
                                fontWeight: FontWeight.w700,
                                color: theme.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 6 : 8,
                              vertical: compact ? 2 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: isUpcoming
                                  ? (theme.isDark
                                      ? AppColors.primary
                                          .withValues(alpha: 0.16)
                                      : const Color(0xFFE8F5E9))
                                  : isPastDue
                                      ? (theme.isDark
                                          ? Colors.amber.withValues(alpha: 0.16)
                                          : Colors.amber.shade50)
                                      : theme.fieldBg,
                              borderRadius:
                                  BorderRadius.circular(compact ? 8 : 12),
                            ),
                            child: Text(
                              getBookingStatus(b),
                              style: GoogleFonts.poppins(
                                fontSize: compact ? 8.5 : 10,
                                fontWeight: FontWeight.w600,
                                color: isUpcoming
                                    ? (theme.isDark
                                        ? AppColors.primaryLight
                                        : const Color(0xFF2E7D32))
                                    : isPastDue
                                        ? (theme.isDark
                                            ? Colors.amber.shade200
                                            : Colors.amber.shade900)
                                        : theme.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!omitDetailLine) ...[
                        SizedBox(height: gapMid),
                        Text(
                          bookingDisplayName(b),
                          style: GoogleFonts.poppins(
                            fontSize: nameFont,
                            fontWeight: FontWeight.w600,
                            color: theme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bookingDisplayConsultationType(b)} · ${bookingDisplayPlatform(b)}',
                          style: GoogleFonts.poppins(
                            fontSize: metaFont,
                            color: theme.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        SizedBox(height: gapMid),
                        Text(
                          '${bookingDisplayName(b)} · ${bookingDisplayConsultationType(b)}',
                          style: GoogleFonts.poppins(
                            fontSize: nameFont,
                            fontWeight: FontWeight.w500,
                            color: theme.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (b['id'] != null && isUpcoming) ...[
                        SizedBox(height: compact ? 3 : 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) =>
                                    buildCancelBookingConfirmDialog(ctx),
                              );
                              if (confirm == true) await _cancelBooking(b);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: Text(
                                'Cancel booking',
                                style: GoogleFonts.poppins(
                                  fontSize: compact ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildRedesignedHealthTipsSection() {
    final theme = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.isDark
              ? theme.border
              : AppColors.primary.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.isDark
                ? Colors.black.withValues(alpha: 0.24)
                : AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.isDark
                    ? [
                        AppColors.primary.withValues(alpha: 0.18),
                        theme.fieldBg,
                      ]
                    : [
                        const Color(0xFFDFF0E4),
                        const Color(0xFFF0FAF3),
                      ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: theme.isDark
                          ? AppColors.primaryLight
                          : AppColors.primaryDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wellness insights',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                        ),
                      ),
                      Text(
                        'Short reads from trusted health guidance.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: theme.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refreshHealthTips,
                  tooltip: 'Refresh tips',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.refresh_rounded,
                      size: 20,
                      color: theme.isDark
                          ? AppColors.primaryLight
                          : AppColors.primaryDark),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: _buildCompactHealthTipsList(),
          ),
        ],
      ),
    );
  }
}

class _PharmacistWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 14);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 4,
      size.width,
      size.height - 14,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PharmacistActionTile extends StatelessWidget {
  const _PharmacistActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final fg = filled
        ? Colors.white
        : (theme.isDark ? AppColors.primaryLight : AppColors.primaryDark);
    final subColor =
        filled ? Colors.white.withValues(alpha: 0.88) : theme.muted;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  )
                : LinearGradient(
                    colors: theme.isDark
                        ? [
                            AppColors.primary.withValues(alpha: 0.16),
                            theme.fieldBg,
                          ]
                        : [
                            const Color(0xFFE8F5E9),
                            const Color(0xFFF8FCF9),
                          ],
                  ),
            border: filled
                ? null
                : Border.all(
                    color: theme.isDark
                        ? AppColors.primary.withValues(alpha: 0.28)
                        : AppColors.primary.withValues(alpha: 0.25),
                  ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: subColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
