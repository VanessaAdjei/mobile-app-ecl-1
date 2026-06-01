// pages/pharmacists.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'app_back_button.dart';
import '../config/app_colors.dart';
import '../widgets/cart_icon_button.dart';
import 'pharmacists/pharmacists_bookings_sheet.dart';
import 'pharmacists/pharmacists_booking_helpers.dart';
import 'pharmacists/pharmacists_ernest_config_dialog.dart';
import 'pharmacists/pharmacists_models.dart';
import 'pharmacists/ernest_chat_page.dart';
import 'pharmacists/simple_ernest_chat_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_tips_service.dart';
import '../models/health_tip.dart';
import '../services/ernest_ai_service.dart';
import '../services/auth_service.dart';
import 'signinpage.dart';
import '../services/booking_service.dart';

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
  bool _isCheckingAuth = true; // Track if auth check is in progress
  bool _shouldHighlightBooking = false;

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
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      setState(() {
        _isUserLoggedIn = isLoggedIn;
        _isCheckingAuth = false;
      });

      if (isLoggedIn) {
        await _loadBookings();
        await _prefillUserData();
      }
    } catch (e) {
      setState(() {
        _isUserLoggedIn = false;
        _isCheckingAuth = false;
      });
      debugPrint('Error checking login status: $e');
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
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
                    colors: [Colors.orange[400]!, Colors.orange[600]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.login,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Login Required',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You need to be logged in to book a consultation with our pharmacists.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
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
                            Navigator.pop(context);
                            _navigateToLogin();
                          },
                          child: Center(
                            child: Text(
                              'Login',
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Welcome back! You can now book consultations.'),
                    ],
                  ),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: Duration(seconds: 3),
                ),
              );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.primary.withOpacity(0.28)),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(iconRadius),
            ),
            child: Icon(Icons.lock_outline_rounded,
                color: AppColors.accent, size: compact ? 16 : 20),
          ),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  compact ? 'Sign in to sync bookings' : 'Sign in to manage bookings',
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                if (!compact)
                  Text(
                    'Use your Ernest account to book and track consultations.',
                    style: GoogleFonts.poppins(
                      fontSize: bodySize,
                      color: const Color(0xFF6B7280),
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

  Widget _buildLoginRequiredButton() {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[500]!, Colors.orange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _showLoginRequiredDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'Login to Book',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking cancelled'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result['message']?.toString() ?? 'Failed to cancel booking'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // drag handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[400]!, Colors.grey[300]!],
                  ),
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
                          color: Colors.grey[800],
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
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Colors.grey[400],
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
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),

                      if (tip.summary != null &&
                          tip.summary != tip.content) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Summary',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                tip.summary!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.green[700],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the link'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening link: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF2FBF6),
                      Color(0xFFE8F2EC),
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
                                      backgroundColor: Colors.white
                                          .withValues(alpha: 0.18),
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
                                  color:
                                      Colors.white.withValues(alpha: 0.88),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
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
              color: current
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2),
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

    return Container(
      key: key,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: AppColors.accent, size: 22),
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
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Greyed-out dates are fully booked or closed.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF4B5563),
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
                color: const Color(0xFFF8FCFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCE5DF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
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
          if (_availableDates.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No open days in the next 30 days. Try again later or contact support.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
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
    final date = _availabilityDate;
    return Container(
      key: key,
      color: Colors.white,
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
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    const Color(0xFFE8F5E9),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMMM d, y').format(date),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
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
              color: const Color(0xFF64748B),
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
                          color: Colors.grey.shade600,
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
                              color: isSelected
                                  ? null
                                  : const Color(0xFFF8FAF9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : const Color(0xFFDCE5DF),
                                width: isSelected ? 1.5 : 1,
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
                                  : null,
                            ),
                            child: Text(
                              t.format(context),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF374151),
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
                disabledBackgroundColor: Colors.grey.shade300,
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
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: AppColors.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your slot is reserved below. Complete the form and submit to confirm.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF374151),
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
                  (value) => setDialogState(
                      () => _selectedConsultationType = value!),
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
              'Reason for visit',
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
                    border: Border.all(color: const Color(0xFFDCE5DF)),
                    color: const Color(0xFFF8FCFA),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMM d, y').format(_selectedDate)} · ${_selectedTime.format(context)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
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

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.blue[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check, color: Colors.white, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fill in your details to book your consultation',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // form section
  Widget _buildFormSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // section title
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Container(
                      height: 2,
                      width: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // section content
          ...children,
        ],
      ),
    );
  }

  // Enhanced Dropdown Field
  Widget _buildEnhancedDropdownField(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(Icons.keyboard_arrow_down, color: color, size: 18),
            dropdownColor: Colors.white,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  // text input field
  Widget _buildEnhancedTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color, {
    String? Function(String?)? validator,
    int maxLines = 1,
    GlobalKey<FormFieldState<dynamic>>? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.grey[100],
              hintText: 'Enter ${label.toLowerCase()}',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  // Enhanced Date Picker
  Widget _buildEnhancedDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_today, color: Colors.orange, size: 16),
            ),
            SizedBox(width: 12),
            Text(
              'Preferred Date',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 30)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.orange[600]!,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                Icon(Icons.calendar_today, color: Colors.orange),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Enhanced Time Picker
  Widget _buildEnhancedTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.access_time, color: Colors.orange, size: 16),
            ),
            SizedBox(width: 12),
            Text(
              'Preferred Time',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.orange[600]!,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              setState(() => _selectedTime = time);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                Icon(Icons.access_time, color: Colors.orange),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedSubmitButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[500]!, Colors.green[600]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _submitBookingWithValidation,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Book Consultation',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 1200.ms).scale(begin: Offset(0.8, 0.8));
  }

  // Simplified form section
  Widget _buildSimpleFormSection(
      String title, IconData sectionIcon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                    color: const Color(0xFF1F2937),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE5DF)),
            color: const Color(0xFFF8FAF9),
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
                    color: const Color(0xFF1F2937),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary, size: 22),
            dropdownColor: Colors.white,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF1F2937),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
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
            fillColor: const Color(0xFFF8FAF9),
            hintText: maxLines > 1 ? null : 'Enter $label',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE5DF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE5DF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  // Simplified date picker
  Widget _buildSimpleDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Date',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d, y').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade900,
                  ),
                ),
                Icon(Icons.calendar_today,
                    color: Colors.grey.shade600, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Simplified time picker
  Widget _buildSimpleTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Time',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
            );
            if (time != null) {
              setState(() => _selectedTime = time);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTime.format(context),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade900,
                  ),
                ),
                Icon(Icons.access_time, color: Colors.grey.shade600, size: 18),
              ],
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all required fields.'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: 4),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Booking failed'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 4),
          ),
        );
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
                      Navigator.pop(context); // Close success dialog
                      Navigator.pop(context); // Close booking form
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

  Widget _buildModernDropdownField(String label, String value,
      List<String> options, Function(String?) onChanged, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon:
                  Icon(Icons.keyboard_arrow_down, color: Colors.green[700]),
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1, String? Function(String?)? validator, Key? fieldKey}) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green[700]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              'Preferred Date',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 30)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.green[700]!,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                Icon(Icons.calendar_today, color: Colors.green[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              'Preferred Time',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
              initialEntryMode: TimePickerEntryMode.input,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    timePickerTheme: TimePickerThemeData(
                      hourMinuteTextColor: Colors.green[700],
                      hourMinuteColor: Colors.green[50],
                      dialHandColor: Colors.green[700],
                      dialBackgroundColor: Colors.green[50],
                      dialTextColor: Colors.green[700],
                      entryModeIconColor: Colors.green[700],
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              setState(() => _selectedTime = time);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTime.format(context),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                Icon(Icons.access_time, color: Colors.green[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton(
      String text, IconData icon, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unified “your bookings” area under the app bar (next visit + actions).
  Widget _buildTopBookingsStrip() {
    final visible = _pharmacistPageBookings;
    if (visible.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: shellBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : const Color(0xFFD4EBDC),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          color: isDark
                              ? Colors.grey.shade200
                              : const Color(0xFF1F2937),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F1),
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: BackButtonUtils.simple(
          backgroundColor: Colors.white.withOpacity(0.2),
        ),
        title: Text(
          'Pharmacist care',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.15,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              child: CartIconButton(
                iconColor: Colors.white,
                iconSize: 22,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          if (_pharmacistPageBookings.isNotEmpty)
            SliverToBoxAdapter(child: _buildTopBookingsStrip()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              _pharmacistPageBookings.isNotEmpty ? 12 : 14,
              16,
              32,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeroSection(),
                const SizedBox(height: 14),
                _buildRedesignedHealthTipsSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EDE6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2.35,
            child: Image.asset(
              'assets/images/banner2.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expert guidance',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Medication help & consultations',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Book a pharmacist session when it works for you.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF3FAF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCEEE2)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Licensed pharmacists · Private · Available anytime',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF4B5563),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _showBookingForm,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Book appointment',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustStat(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrustDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withOpacity(0.25),
      margin: EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _buildModernSectionHeader(
      String title, IconData icon, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionHeaderWithRefresh(
      String title, IconData icon, String subtitle, VoidCallback onRefresh) {
    return Container(
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onRefresh,
              icon: Icon(Icons.refresh, color: Colors.white, size: 18),
              tooltip: 'Refresh',
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernVirtualAssistantCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.purple[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[500]!, Colors.purple[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Ernest',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                    Text(
                      'Your AI Health Companion',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Features list
          Column(
            children: [
              _buildFeatureRow(
                Icons.lightbulb_outline,
                'Instant Health Tips',
                'Get personalized recommendations',
                Colors.amber[600]!,
              ),
              SizedBox(height: 12),
              _buildFeatureRow(
                Icons.medical_services,
                'Symptom Analysis',
                'Understand your health concerns',
                Colors.blue[600]!,
              ),
              SizedBox(height: 12),
              _buildFeatureRow(
                Icons.medication,
                'Medication Guidance',
                'Learn about your prescriptions',
                Colors.green[600]!,
              ),
              SizedBox(height: 12),
              _buildFeatureRow(
                Icons.psychology,
                'Wellness Advice',
                'Mental health & lifestyle tips',
                Colors.teal[600]!,
              ),
            ],
          ),
          SizedBox(height: 20),

          // Action button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple[500]!,
                  Colors.purple[600]!,
                  Colors.purple[700]!
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openVirtualAssistant,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ask Ernest AI',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openVirtualAssistant() async {
    // Simple chat page without AI integration
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleErnestChatPage(),
      ),
    );

    // If user pressed Book Appointment, open the form directly
    if (result == 'open_form' && mounted) {
      _showBookingForm();
    } else if (result == true && mounted) {
      // Legacy: highlight the booking box
      setState(() {
        _shouldHighlightBooking = true;
      });

      // Remove highlight after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _shouldHighlightBooking = false;
          });
        }
      });
    }
  }

  void _testErnestConnection() async {
    try {
      final result = await ErnestAIService.testConnection();

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Ernest AI connection successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection failed: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _testAlternativeModels() async {
    try {
      final result = await ErnestAIService.testAlternativeModels();

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Found working model: ${result['working_model']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ All models failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showErnestChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ErnestChatPage(),
      ),
    );
  }

  Widget _buildModernPlatformSelection() {
    return Column(
      children: [
        _buildModernPlatformOption(
          'Video Call',
          Icons.video_call,
          Colors.blue,
          'Face-to-face consultation',
          _selectedConsultationType == 'Video Call',
          () => setState(() => _selectedConsultationType = 'Video Call'),
        ),
        SizedBox(height: 8),
        _buildModernPlatformOption(
          'Audio Call',
          Icons.call,
          Colors.green,
          'Voice consultation',
          _selectedConsultationType == 'Audio Call',
          () => setState(() => _selectedConsultationType = 'Audio Call'),
        ),
        SizedBox(height: 8),
        _buildModernPlatformOption(
          'Chat',
          Icons.chat,
          Colors.orange,
          'Text messaging',
          _selectedConsultationType == 'Chat',
          () => setState(() => _selectedConsultationType = 'Chat'),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildModernPlatformOption(String title, IconData icon, Color color,
      String description, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.1),
                    color.withValues(alpha: 0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey[50],
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 14,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.grey[800],
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Consolidated Services Card - Combines Virtual Consultation and Ernest AI
  Widget _buildConsolidatedServicesCard() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFFE5EEF7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultation Hub',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Choose pharmacist consultation or AI guidance.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildServiceTile(
                  title: 'Book Consultation',
                  subtitle: 'Video, Audio, and Chat support',
                  badge: '24/7 available',
                  icon: Icons.video_call_rounded,
                  primary: Color(0xFF2E7D32),
                  secondary: Color(0xFF66BB6A),
                  onTap: _showBookingForm,
                  highlighted: _shouldHighlightBooking,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildServiceTile(
                  title: 'Ask Ernest AI',
                  subtitle: 'Get quick health guidance',
                  badge: 'Instant answers',
                  icon: Icons.smart_toy_rounded,
                  primary: Color(0xFFF57C00),
                  secondary: Color(0xFFFFB74D),
                  onTap: _openVirtualAssistant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color primary,
    required Color secondary,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: highlighted
                ? [primary, secondary]
                : [primary.withOpacity(0.08), secondary.withOpacity(0.14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? Colors.white.withOpacity(0.4)
                : primary.withOpacity(0.28),
            width: highlighted ? 1.4 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(highlighted ? 0.28 : 0.12),
              blurRadius: highlighted ? 14 : 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    highlighted ? Colors.white.withOpacity(0.22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: highlighted ? Colors.white : primary,
                size: 26,
              ),
            ),
            SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: highlighted ? Colors.white : Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: highlighted
                    ? Colors.white.withOpacity(0.9)
                    : Color(0xFF4B5563),
                height: 1.25,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: highlighted
                    ? Colors.white.withOpacity(0.2)
                    : primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? Colors.white : primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplifiedHealthInsightsCard() {
    if (_isLoadingHealthTips) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                    strokeWidth: 2,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading health insights...',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.green[700],
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
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[50]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.health_and_safety,
                  size: 28,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No health insights available',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green[50]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[500]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.article,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Health Insights',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _refreshHealthTips,
                    icon: Icon(Icons.refresh, size: 18, color: Colors.white),
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Enhanced Health Tips
          ...(_healthTips
              .take(2)
              .map((tip) => _buildEnhancedHealthTipItem(tip))),
          if (_healthTips.length > 2)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green[600], size: 16),
                  SizedBox(width: 8),
                  Text(
                    '${_healthTips.length - 2} more insights available',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHealthTipItem(HealthTip tip) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          if (tip.imageUrl != null && tip.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  tip.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackImage(tip.category);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            _buildFallbackImage(tip.category),

          // Content Section
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _getCategoryColor(tip.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getCategoryColor(tip.category)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(tip.category),
                    color: _getCategoryColor(tip.category),
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(tip.category)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getCategoryColor(tip.category)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          tip.category,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _getCategoryColor(tip.category),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (tip.summary != null && tip.summary!.isNotEmpty) ...[
                        SizedBox(height: 6),
                        Text(
                          tip.summary!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  // Helper method to get category-specific colors
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'nutrition':
      case 'diet':
        return Colors.orange;
      case 'exercise':
      case 'physical activity':
        return Colors.blue;
      case 'mental health':
        return Colors.purple;
      case 'prevention':
        return Colors.green;
      case 'wellness':
        return Colors.teal;
      case 'heart health':
      case 'cardiovascular':
        return Colors.red;
      case 'diabetes':
        return Colors.orange;
      case 'pregnancy':
      case 'women\'s health':
        return Colors.pink;
      default:
        return Colors.green;
    }
  }

  // Helper method to get category-specific icons
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'nutrition':
      case 'diet':
        return Icons.restaurant;
      case 'exercise':
      case 'physical activity':
        return Icons.fitness_center;
      case 'mental health':
        return Icons.psychology;
      case 'prevention':
        return Icons.shield;
      case 'wellness':
        return Icons.health_and_safety;
      case 'heart health':
      case 'cardiovascular':
        return Icons.favorite;
      case 'diabetes':
        return Icons.monitor_heart;
      case 'pregnancy':
      case 'women\'s health':
        return Icons.pregnant_woman;
      default:
        return Icons.health_and_safety;
    }
  }

  // Fallback image when no image URL is available
  Widget _buildFallbackImage(String category) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getCategoryColor(category).withValues(alpha: 0.1),
            _getCategoryColor(category).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              category,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _getCategoryColor(category),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleHealthTipItem(HealthTip tip) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.health_and_safety,
            color: Colors.green[600],
            size: 16,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              tip.title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    final v = _categoryVisualsForTip(tip);
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      color: v.accent,
                    ),
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: resolvedImageUrl!,
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
                        color: v.accent,
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
                        color: const Color(0xFF111827),
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
                        color: const Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHealthTipsList() {
    if (_isLoadingHealthTips) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading tips…',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
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
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 22, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No tips yet. Pull refresh above.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
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
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tips.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: const Color(0xFFE8F0EA),
              ),
            _buildCompactHealthTipRow(tips[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildModernHealthTipCard(HealthTip tip) {
    // Get appropriate icon and color based on category
    IconData icon;
    Color primaryColor;
    Color accentColor;

    switch (tip.category.toLowerCase()) {
      case 'nutrition':
      case 'diet':
        icon = Icons.restaurant;
        primaryColor = Colors.orange[600]!;
        accentColor = Colors.orange[100]!;
        break;
      case 'exercise':
      case 'physical activity':
        icon = Icons.fitness_center;
        primaryColor = Colors.blue[600]!;
        accentColor = Colors.blue[100]!;
        break;
      case 'mental health':
        icon = Icons.psychology;
        primaryColor = Colors.purple[600]!;
        accentColor = Colors.purple[100]!;
        break;
      case 'prevention':
        icon = Icons.shield;
        primaryColor = Colors.green[600]!;
        accentColor = Colors.green[100]!;
        break;
      case 'wellness':
        icon = Icons.health_and_safety;
        primaryColor = Colors.teal[600]!;
        accentColor = Colors.teal[100]!;
        break;
      case 'heart health':
      case 'cardiovascular':
        icon = Icons.favorite;
        primaryColor = Colors.red[600]!;
        accentColor = Colors.red[100]!;
        break;
      case 'diabetes':
        icon = Icons.monitor_heart;
        primaryColor = Colors.orange[600]!;
        accentColor = Colors.orange[100]!;
        break;
      case 'pregnancy':
      case 'women\'s health':
        icon = Icons.pregnant_woman;
        primaryColor = Colors.pink[600]!;
        accentColor = Colors.pink[100]!;
        break;
      default:
        icon = Icons.health_and_safety;
        primaryColor = Colors.green[600]!;
        accentColor = Colors.green[100]!;
    }

    return InkWell(
      onTap: tip.url.isNotEmpty ? () => _showHealthTipDetails(tip) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section with image and category badge
            Stack(
              children: [
                // Image container
                Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    color: accentColor,
                  ),
                  child: tip.imageUrl != null && tip.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: Image.network(
                            tip.imageUrl!,
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                ),
                                child: Icon(
                                  icon,
                                  color: primaryColor,
                                  size: 32,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Icon(
                          icon,
                          color: primaryColor,
                          size: 24,
                        ),
                ),
                // Category badge positioned at top-right with smaller size
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      tip.category.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Content section
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with icon
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            icon,
                            color: primaryColor,
                            size: 10,
                          ),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tip.title,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    // Summary text
                    Text(
                      tip.summary ?? tip.content,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.grey[600],
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    // Action button
                    if (tip.url.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withValues(alpha: 0.8)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Learn More',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildSlimBookingCard(
    Map<String, dynamic> b, {
    EdgeInsetsGeometry margin =
        const EdgeInsets.symmetric(horizontal: 16),
    bool compact = false,
    bool omitDetailLine = false,
  }) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isUpcoming
              ? AppColors.primary.withOpacity(0.35)
              : isPastDue
                  ? Colors.amber.shade200
                  : Colors.grey.shade200,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                                color: Color(0xFF1F2937),
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
                                  ? Color(0xFFE8F5E9)
                                  : isPastDue
                                      ? Colors.amber.shade50
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(
                                  compact ? 8 : 12),
                            ),
                            child: Text(
                              getBookingStatus(b),
                              style: GoogleFonts.poppins(
                                fontSize: compact ? 8.5 : 10,
                                fontWeight: FontWeight.w600,
                                color: isUpcoming
                                    ? Color(0xFF2E7D32)
                                    : isPastDue
                                        ? Colors.amber.shade900
                                        : Colors.grey.shade700,
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
                            color: Color(0xFF374151),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bookingDisplayConsultationType(b)} · ${bookingDisplayPlatform(b)}',
                          style: GoogleFonts.poppins(
                            fontSize: metaFont,
                            color: Colors.grey.shade600,
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
                            color: const Color(0xFF4B5563),
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
                                  color: Colors.red.shade600,
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

  Widget _buildEnhancedBookingCard(Map<String, dynamic> b) {
    final isUpcoming = isBookingUpcoming(b);
    final isPastDue = isBookingPastDue(b);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date/time and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[500]!, Colors.green[600]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${bookingDisplayDate(b)} at ${bookingDisplayTime(b)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: isUpcoming
                        ? LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[500]!],
                          )
                        : null,
                    color: isUpcoming
                        ? null
                        : isPastDue
                            ? Colors.amber.shade100
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isUpcoming
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    getBookingStatus(b),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isUpcoming
                          ? Colors.white
                          : isPastDue
                              ? Colors.amber.shade900
                              : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Details grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.person,
                    'Name',
                    bookingDisplayName(b),
                    Colors.blue[600]!,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildDetailItem(
                    Icons.phone,
                    'Phone',
                    b['phone'] ?? '',
                    Colors.green[600]!,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.email,
                    'Email',
                    b['email'] ?? '',
                    Colors.orange[600]!,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    Icons.video_call,
                    'Type',
                    bookingDisplayConsultationType(b),
                    Colors.purple[600]!,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Symptoms section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: Colors.red[600],
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Symptoms/Concerns',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    bookingDisplaySymptoms(b),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final isUpcoming = isBookingUpcoming(b);
    final isPastDue = isBookingPastDue(b);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.green[700], size: 15),
                    SizedBox(width: 6),
                    Text(
                      '${bookingDisplayDate(b)} at ${bookingDisplayTime(b)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? Colors.green[100]
                        : isPastDue
                            ? Colors.amber.shade100
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    getBookingStatus(b),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isUpcoming
                          ? Colors.green[800]
                          : isPastDue
                              ? Colors.amber.shade900
                              : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.person, color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    bookingDisplayName(b),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['phone'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.email, color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['email'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.video_call, color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    bookingDisplayConsultationType(b),
                    style: GoogleFonts.poppins(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.computer, color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Platform: ${bookingDisplayPlatform(b)}',
                    style: GoogleFonts.poppins(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.medical_services,
                    color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    bookingDisplaySymptoms(b),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedesignedHealthTipsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFF5FBF7),
            Colors.white,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6D0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily wellness picks',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tap a row for a short read from trusted guidance.',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _refreshHealthTips,
                tooltip: 'New tips',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accent,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactHealthTipsList(),
        ],
      ),
    );
  }
}
