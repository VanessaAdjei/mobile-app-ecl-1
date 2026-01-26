// pages/pharmacists.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'app_back_button.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/app_header_bar.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/health_tips_service.dart';
import '../models/health_tip.dart';
import '../services/ernest_ai_service.dart';
import 'auth_service.dart';
import 'signinpage.dart';

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

  Future<void> _loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final bookingsJson = prefs.getStringList('pharmacist_bookings') ?? [];
    setState(() {
      _bookings = bookingsJson
          .map((e) => Map<String, dynamic>.from(_decodeJson(e)))
          .toList();
    });
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

  Widget _buildLoginPromptCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[50]!, Colors.orange[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.login,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login Required',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      Text(
                        'Sign in to book consultations',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[500]!, Colors.orange[600]!],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _navigateToLogin,
                  child: Center(
                    child: Text(
                      'Login Now',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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
    // Allow booking without login requirement
    await _prepareAvailabilityForBooking();
    await _prefillUserData();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Dialog content must manage its own state; page setState won't
        // rebuild this route. Use StatefulBuilder to update steps.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final topPadding = MediaQuery.of(context).padding.top;
            return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Column(
                    children: [
                      // Green header
                      Container(
                        padding: EdgeInsets.only(top: topPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade600,
                              Colors.green.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios,
                                      size: 20, color: Colors.white),
                                  onPressed: () {
                                    if (_bookingStep > 0) {
                                      setDialogState(() {
                                        _bookingStep -= 1;
                                      });
                                      return;
                                    }
                                    Navigator.pop(context);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _bookingStep == 0
                                        ? 'Select a Date'
                                        : _bookingStep == 1
                                            ? 'Select a Time'
                                            : 'Book Consultation',
                                    style: const TextStyle(
                                      fontSize: 22,
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

                      // Step content
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _bookingStep == 0
                              ? _buildSelectDateStep(
                                  key: const ValueKey('step0'),
                                  setDialogState: setDialogState,
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
                    ],
                  ),
                ));
          },
        );
      },
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
    final start = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final end = start.add(const Duration(days: 30));

    final dates = <DateTime>[];
    for (var d = start;
        d.isBefore(end);
        d = d.add(const Duration(days: 1))) {
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
    for (final b in _bookings) {
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

  Widget _buildSelectDateStep({Key? key, required StateSetter setDialogState}) {
    final now = DateTime.now();
    final firstDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final lastDate = firstDate.add(const Duration(days: 30));
    final initialDate = _availabilityDate ??
        (_availableDates.isNotEmpty ? _availableDates.first : firstDate);

    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available dates',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a date to see available times.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
          if (_availableDates.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No available dates found in the next 30 days.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _availabilityDate == null
                  ? null
                  : () {
                      final times =
                          _computeAvailableTimesForDate(_availabilityDate!);
                      setDialogState(() {
                        _availableTimes = times;
                        _availabilityTime = null;
                        _bookingStep = 1;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Next',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date != null) ...[
            Text(
              DateFormat('EEE, MMM d, y').format(date),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            'Available times',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _availableTimes.isEmpty
                ? Center(
                    child: Text(
                      'No available times for this date.',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _availableTimes.length,
                    itemBuilder: (context, index) {
                      final t = _availableTimes[index];
                      final isSelected = _availabilityTime != null &&
                          _timeKey(t) == _timeKey(_availabilityTime!);
                      return InkWell(
                        onTap: () =>
                            setDialogState(() => _availabilityTime = t),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.green.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            t.format(context),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _availabilityDate == null || _availabilityTime == null
                  ? null
                  : () {
                      setDialogState(() {
                        _selectedDate = _availabilityDate!;
                        _selectedTime = _availabilityTime!;
                        _bookingStep = 2;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Continue to form',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingFormStep({Key? key, required StateSetter setDialogState}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Consultation Details
            _buildSimpleFormSection(
              'Consultation Details',
              [
                _buildSimpleDropdownField(
                  'Mode of Consultation',
                  _selectedConsultationType,
                  _consultationTypes,
                  (value) =>
                      setState(() => _selectedConsultationType = value!),
                ),
                const SizedBox(height: 12),
                _buildSimpleDropdownField(
                  'Preferred Platform',
                  _selectedPreferredPlatform,
                  _preferredPlatforms,
                  (value) =>
                      setState(() => _selectedPreferredPlatform = value!),
                ),
                const SizedBox(height: 12),
                _buildSimpleDropdownField(
                  'Gender Preference',
                  _selectedGenderPreference,
                  _genderPreferences,
                  (value) =>
                      setState(() => _selectedGenderPreference = value!),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Personal Information
            _buildSimpleFormSection(
              'Personal Information',
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
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Medical Information
            _buildSimpleFormSection(
              'Medical Information',
              [
                _buildSimpleTextField(
                  'Symptoms/Concerns',
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
            const SizedBox(height: 16),

            // Schedule (locked in)
            _buildSimpleFormSection(
              'Schedule',
              [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: Colors.grey.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMM d, y').format(_selectedDate)} at ${_selectedTime.format(context)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
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
                          _refreshAvailableDates(dialogSetState: setDialogState);
                        },
                        child: Text(
                          'Change',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit button
            _buildSimpleSubmitButton(),
            const SizedBox(height: 20),
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
  Widget _buildSimpleFormSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade900,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(Icons.keyboard_arrow_down,
                color: Colors.grey.shade600, size: 20),
            dropdownColor: Colors.white,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade900,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
              hintText: 'Enter $label',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade900,
            ),
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
      child: ElevatedButton(
        onPressed: _submitBookingWithValidation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Book Consultation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _submitBookingWithValidation() async {
    // Allow booking without login requirement
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      // Scroll to the first invalid field
      if (_nameController.text.isEmpty) {
        _scrollToField(_nameFieldKey);
      } else if (_phoneController.text.isEmpty) {
        _scrollToField(_phoneFieldKey);
      } else if (_emailController.text.isEmpty) {
        _scrollToField(_emailFieldKey);
      } else if (_symptomsController.text.isEmpty) {
        _scrollToField(_symptomsFieldKey);
      }
      // Show validation errors
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
    // Save booking
    final booking = {
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
    setState(() {
      _bookings.insert(0, booking);
    });
    await _saveBookings();
    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(),
    );
    // Simulate API call
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog
      _showSuccessDialog();
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(children: [
        Column(children: [
          // Unified app header
          AppHeaderBar(
            title: 'Meet the Pharmacists',
            subtitle: 'Get expert advice from our pharmacists',
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                // My Booked Appointments Section
                if (_bookings.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: Row(
                      children: [
                        if (_bookings.length > 1)
                          Expanded(
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24)),
                                      ),
                                      builder: (_) => BookingsListSheet(
                                        bookings: _bookings,
                                        onClear: _clearBookings,
                                      ),
                                    );
                                  },
                                  child: Center(
                                    child: Text(
                                      'See All (${_bookings.length})',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_bookings.length > 1) SizedBox(width: 6),
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: _clearBookings,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.clear_all,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Clear',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
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
                    ),
                  ),
                  _isUserLoggedIn
                      ? _buildSlimBookingCard(_bookings.first)
                      : _buildLoginPromptCard(),
                ],
                // Main Content
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      // Hero Section
                      _buildHeroSection(),
                      SizedBox(height: 10),

                      SizedBox(height: 22),
                      _buildConsolidatedServicesCard(),
                      SizedBox(height: 48),

                      // Health Tips Section
                      _buildRedesignedHealthTipsSection(),
                      // Space for floating bot
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.green.shade100,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.medical_services,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional Healthcare',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get expert advice from our experienced pharmacists with 24/7 support.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildFeatureBadge(
                  Icons.check_circle, 'Expert Advice', Colors.green.shade700),
              _buildFeatureBadge(
                  Icons.access_time, '24/7 Support', Colors.grey.shade700),
              _buildFeatureBadge(
                  Icons.security, 'Secure & Private', Colors.red.shade600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text, Color color) {
    final isRed = color == Colors.red.shade600;
    final isGreen = color == Colors.green.shade700;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isRed
            ? Colors.red.shade50
            : isGreen
                ? Colors.green.shade50
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRed
              ? Colors.red.shade200
              : isGreen
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
        builder: (context) => SimpleErnestChatPage(),
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
        builder: (context) => ErnestChatPage(),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.shade100,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Healthcare Services',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Consultation & AI assistance',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Compact Service Options
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showBookingForm,
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          height: 160,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _shouldHighlightBooking
                                  ? Colors.green.shade400
                                  : Colors.grey.shade200,
                              width: _shouldHighlightBooking ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _shouldHighlightBooking
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: _shouldHighlightBooking ? 8 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.green.shade100,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.video_call,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Book Consultation',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Video, Audio & Chat',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '24/7 Available',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Border overlay that doesn't affect container size
                        if (_shouldHighlightBooking)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.yellow[600]!,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Ernest AI
                Expanded(
                  child: InkWell(
                    onTap: _openVirtualAssistant,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 160,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.shade100,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ask Ernest',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 3),
                          Text(
                            'AI health tips',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Instant Help',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
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
        ],
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

  Widget _buildModernHealthBlogsSection() {
    if (_isLoadingHealthTips) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading health tips...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_healthTips.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'No health tips available',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _healthTips.length,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: 16),
            child: _buildRedesignedHealthTipCard(_healthTips[index]),
          );
        },
      ),
    );
  }

  Widget _buildRedesignedHealthTipCard(HealthTip tip) {
    // Get appropriate icon and color based on category
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

    return GestureDetector(
      onTap: tip.url.isNotEmpty ? () => _showHealthTipDetails(tip) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: accentColor,
              ),
              child: tip.imageUrl != null && tip.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Image.network(
                        tip.imageUrl!,
                        width: double.infinity,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                icon,
                                color: primaryColor,
                                size: 32,
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryColor),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                    ),
            ),

            // Header with icon and category
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tip.category.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      tip.title,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        height: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1),

                    // Summary
                    Expanded(
                      child: Text(
                        tip.summary ?? tip.content,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          height: 1.0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    SizedBox(height: 2),

                    // Action button
                    if (tip.url.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 6,
                              color: primaryColor,
                            ),
                            SizedBox(width: 1),
                            Text(
                              'Learn More',
                              style: GoogleFonts.poppins(
                                fontSize: 7,
                                color: primaryColor,
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

  Widget _buildSlimBookingCard(Map<String, dynamic> b) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact header
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.green[600], size: 14),
                SizedBox(width: 6),
                Text(
                  '${b['date']} at ${b['time']}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: getBookingStatus(b) == 'Upcoming'
                        ? Colors.green[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    getBookingStatus(b),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: getBookingStatus(b) == 'Upcoming'
                          ? Colors.green[700]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Compact details
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue[600], size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['name'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.phone, color: Colors.green[600], size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['phone'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, color: Colors.orange[600], size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['email'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.video_call, color: Colors.purple[600], size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['consultationType'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Compact symptoms
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.medical_services, color: Colors.red[600], size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['symptoms'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                      height: 1.2,
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

  Widget _buildEnhancedBookingCard(Map<String, dynamic> b) {
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
                      '${b['date']} at ${b['time']}',
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
                    gradient: getBookingStatus(b) == 'Upcoming'
                        ? LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[500]!],
                          )
                        : null,
                    color: getBookingStatus(b) == 'Upcoming'
                        ? null
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: getBookingStatus(b) == 'Upcoming'
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
                      color: getBookingStatus(b) == 'Upcoming'
                          ? Colors.white
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
                    b['name'] ?? '',
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
                    b['consultationType'] ?? '',
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
                    b['symptoms'] ?? '',
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
                      '${b['date']} at ${b['time']}',
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
                    color: getBookingStatus(b) == 'Upcoming'
                        ? Colors.green[100]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    getBookingStatus(b),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: getBookingStatus(b) == 'Upcoming'
                          ? Colors.green[800]
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
                    b['name'] ?? '',
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
                    b['consultationType'] ?? '',
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
                    'Platform: ${b['preferredPlatform'] ?? 'Not specified'}',
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
                    b['symptoms'] ?? '',
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.white,
            Colors.blue.shade50,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Tips',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Expert health advice & insights',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _refreshHealthTips,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Refresh',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Content
          if (_isLoadingHealthTips)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.green.shade600,
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Loading health tips...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildModernHealthBlogsSection(),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class BookingsListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onClear;
  const BookingsListSheet(
      {required this.bookings, required this.onClear, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16, left: 0, right: 0, bottom: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'All Booked Appointments',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (context, i) => _BookingCardModal(bookings[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: TextButton(
                onPressed: onClear,
                child: Text('Clear All', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCardModal extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BookingCardModal(this.b);
  @override
  Widget build(BuildContext context) {
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
                      '${b['date']} at ${b['time']}',
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
                    color: getBookingStatus(b) == 'Upcoming'
                        ? Colors.green[100]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    getBookingStatus(b),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: getBookingStatus(b) == 'Upcoming'
                          ? Colors.green[800]
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
                    b['name'] ?? '',
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
                Icon(Icons.video_call, color: Colors.green[400], size: 13),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b['consultationType'] ?? '',
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
                    'Platform: ${b['preferredPlatform'] ?? 'Not specified'}',
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
                    b['symptoms'] ?? '',
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
}

// Helper to determine booking status (move to top-level for global access)
String getBookingStatus(Map<String, dynamic> b) {
  try {
    final parts = (b['date'] ?? '').split('/');
    final timeStr = b['time'] ?? '';
    if (parts.length == 3 && timeStr.isNotEmpty) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 2000;
      final now = DateTime.now();
      // Parse time (e.g., "2:30 PM")
      final timeParts = timeStr.split(' ');
      final hm = timeParts[0].split(':');
      int hour = int.tryParse(hm[0]) ?? 0;
      int minute = int.tryParse(hm[1]) ?? 0;
      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'PM' &&
          hour < 12) {
        hour += 12;
      }
      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      final bookingDate = DateTime(year, month, day, hour, minute);
      if (bookingDate.isAfter(now)) return 'Upcoming';
      return 'Completed';
    }
  } catch (_) {
    // ignore errors and fall through to default
  }
  return 'Upcoming';
}

// Ernest AI Configuration Dialog
class ErnestConfigurationDialog extends StatefulWidget {
  @override
  _ErnestConfigurationDialogState createState() =>
      _ErnestConfigurationDialogState();
}

class _ErnestConfigurationDialogState extends State<ErnestConfigurationDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isConfiguring = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Icon
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.purple[600]!],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 48,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Configure Ask Ernest',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'To use Ernest, you need a Google Gemini API key. Get one for free at:\nhttps://makersuite.google.com/app/apikey',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // API Key Input
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Google Gemini API Key',
                hintText: 'Enter your API key here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.key, color: Colors.purple[600]),
              ),
              obscureText: true,
            ),

            if (_errorMessage != null) ...[
              SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],

            SizedBox(height: 24),

            // Action Buttons
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
                        colors: [Colors.purple[500]!, Colors.purple[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isConfiguring ? null : _configureService,
                        child: Center(
                          child: _isConfiguring
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Configure',
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
    );
  }

  Future<void> _configureService() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your API key';
      });
      return;
    }

    setState(() {
      _isConfiguring = true;
      _errorMessage = null;
    });

    try {
      final success = await ErnestAIService.configure(_apiKeyController.text);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ernest AI configured successfully! 🎉'),
            backgroundColor: Colors.green[600],
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid API key. Please check and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Configuration failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isConfiguring = false;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}

// Ernest AI Chat Page
class ErnestChatPage extends StatefulWidget {
  @override
  _ErnestChatPageState createState() => _ErnestChatPageState();
}

class _ErnestChatPageState extends State<ErnestChatPage> {
  final TextEditingController _questionController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text:
          'Hello! I\'m Ernest, your AI health assistant. How can I help you today? Remember, I provide general wellness advice only. For medical concerns, please consult a healthcare professional.',
      isUser: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Ask Ernest',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Quick questions
          if (_messages.length == 1) _buildQuickQuestions(),

          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          hintText: 'Type your question...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: (_) => _askQuestion(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade600.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isLoading ? null : _askQuestion,
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 1),
              ),
              child: Icon(Icons.smart_toy_rounded,
                  color: Colors.green.shade700, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.green.shade600 : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: message.isUser ? Colors.white : Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Icon(Icons.person_rounded,
                  color: Colors.grey.shade700, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Questions',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HealthCategories.categories.map((category) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _askQuickQuestion(category),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.green.shade200, width: 1),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _askQuickQuestion(String category) {
    final question = HealthCategories.categoryQuestions[category];
    if (question != null) {
      _questionController.text = question;
      _askQuestion();
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: question, isUser: true));
      _isLoading = true;
    });
    _questionController.clear();

    try {
      final response = await ErnestAIService.askQuestion(question);
      setState(() {
        _messages.add(ChatMessage(text: response.message, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ernest Settings'),
        content: Text('Manage your Ernest AI configuration'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearConfiguration();
            },
            child: Text('Clear Configuration'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearConfiguration() async {
    final success = await ErnestAIService.clearConfiguration();
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuration cleared'),
          backgroundColor: Colors.orange[600],
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }
}

// Simple Ernest Chat Page (No AI Integration)
class SimpleErnestChatPage extends StatefulWidget {
  @override
  _SimpleErnestChatPageState createState() => _SimpleErnestChatPageState();
}

class _SimpleErnestChatPageState extends State<SimpleErnestChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<SimpleChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add comprehensive welcome message for first-time users
    _messages.add(SimpleChatMessage(
      text:
          "Hi! I'm Ernest, your virtual health assistant. 👋\n\nI'm here to provide general health information and guidance. I can help with:\n• Common health questions\n• Wellness tips\n• General medical advice\n• Health education ",
      isUser: false,
      timestamp: DateTime.now(),
      showYesNoButtons: false,
    ));

    // Add follow-up message explaining what Ernest can't do
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(SimpleChatMessage(
            text:
                "💡 Tip: If I can't help with your specific concern, I'll guide you to book an appointment with our qualified pharmacists for personalized care.",
            isUser: false,
            timestamp: DateTime.now(),
            showYesNoButtons: false,
          ));
        });
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(SimpleChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
        showYesNoButtons: false,
      ));
      _isTyping = true;
    });
    _messageController.clear();

    // Simulate Ernest typing and responding
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          String response = _getErnestResponse(message);
          _messages.add(SimpleChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            showYesNoButtons: false,
          ));

          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _messages.add(SimpleChatMessage(
                  text:
                      "💊 How are you feeling now? Did that help with your concern?",
                  isUser: false,
                  timestamp: DateTime.now(),
                  showYesNoButtons: true,
                ));
              });
            }
          });
        });
      }
    });
  }

  // Removed _shouldSuggestAppointment method

  void _navigateToAppointment() {
    // Close the chat page and return a signal to open the booking form
    Navigator.pop(context, 'open_form');
  }

  void _handleYesResponse() {
    setState(() {
      _messages.add(SimpleChatMessage(
        text:
            "Great! I'm glad I could help! 😊\n\nIf you need anything else in the future, feel free to chat with me again or book an appointment with our pharmacists.",
        isUser: false,
        timestamp: DateTime.now(),
        showYesNoButtons: false,
      ));
    });

    // Close chat after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _handleNoResponse() {
    setState(() {
      _messages.add(SimpleChatMessage(
        text:
            "I understand your problem hasn't been solved yet. 😔\n\nLet me help you further. What else would you like to know, or would you prefer to book an appointment with our pharmacists for personalized care?",
        isUser: false,
        timestamp: DateTime.now(),
        showYesNoButtons: false,
      ));
    });
  }

  // Show cashback notification
  void _showCashbackNotification(double amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: Colors.green[700],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🎉 Cashback Received!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You\'ve earned ₵${amount.toStringAsFixed(2)} cashback!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                icon: Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 5),
        margin: EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  String _getErnestResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('hello') || message.contains('hi')) {
      return "Hello! How are you feeling today?";
    } else if (message.contains('headache') || message.contains('head pain')) {
      return "I'm sorry to hear about your headache. Common causes include stress, dehydration, or eye strain. Try resting in a quiet, dark room and staying hydrated. If it persists, consider consulting a healthcare provider.";
    } else if (message.contains('fever') || message.contains('temperature')) {
      return "Fever can be a sign of infection. Monitor your temperature and stay hydrated. If it's above 103°F (39.4°C) or persists for more than 3 days, seek medical attention.";
    } else if (message.contains('cough') || message.contains('cold')) {
      return "For coughs and colds, rest, stay hydrated, and consider over-the-counter remedies. If symptoms are severe or persist, consult a healthcare provider.";
    } else if (message.contains('sleep') || message.contains('insomnia')) {
      return "Good sleep is crucial for health. Try maintaining a regular sleep schedule, avoiding screens before bed, and creating a relaxing bedtime routine.";
    } else if (message.contains('diet') || message.contains('nutrition')) {
      return "A balanced diet with fruits, vegetables, lean proteins, and whole grains supports overall health. Consider consulting a nutritionist for personalized advice.";
    } else if (message.contains('exercise') || message.contains('workout')) {
      return "Regular exercise is great for health! Aim for at least 150 minutes of moderate activity weekly. Start slowly and gradually increase intensity.";
    } else if (message.contains('stress') || message.contains('anxiety')) {
      return "Stress and anxiety are common. Try deep breathing, meditation, or talking to someone you trust. If it's overwhelming, consider professional help.";
    } else if (message.contains('thank')) {
      return "You're welcome! I'm here to help. Is there anything else you'd like to know?";
    } else if (message.contains('appointment') ||
        message.contains('book') ||
        message.contains('consult') ||
        message.contains('help') ||
        message.contains('need help') ||
        message.contains('how to book') ||
        message.contains('booking') ||
        message.contains('schedule')) {
      return "I'd be happy to help you book an appointment! 📅\n\n**Quick Steps:**\n1️⃣ Tap 'Book Appointment' below\n2️⃣ Choose consultation type (Video Call/Audio Call/Chat)\n3️⃣ Select preferred platform (Zoom/Google Meet/WhatsApp/Phone)\n4️⃣ Pick date & time\n5️⃣ Fill details & submit\n\nOur pharmacists are available 24/7!";
    } else if (message.contains('pain') ||
        message.contains('severe') ||
        message.contains('emergency')) {
      return "I'm concerned about your symptoms. For pain, severe symptoms, or emergency situations, please:\n\n🚨 Seek immediate medical attention if symptoms are severe\n🏥 Contact emergency services if needed\n💊 Book an appointment with our pharmacists for non-emergency concerns\n\nYour health and safety come first!";
    } else if (message.contains('medication') ||
        message.contains('prescription') ||
        message.contains('drug')) {
      return "I can provide general information about medications, but for specific prescription advice, drug interactions, or dosage questions, please consult with our pharmacists. They have the expertise to give you personalized medication guidance.";
    } else if (message.contains('diagnosis') ||
        message.contains('condition') ||
        message.contains('disease')) {
      return "I cannot diagnose medical conditions or diseases. For proper diagnosis and treatment, please book an appointment with our pharmacists or consult a healthcare provider. They can perform proper assessments and provide accurate medical guidance.";
    } else if (message.contains('help') || message.contains('support')) {
      return "I'm here to help! 🤝\n\n**I can assist with:**\n• Health information & tips\n• Symptom understanding\n• **Booking appointments**\n• Health education\n\n💡 For personalized advice, book with our pharmacists for:\n• Individual assessment\n• Tailored guidance\n• Specific medical questions\n\nNeed help with any of these?";
    } else {
      return "That's an interesting question! While I can provide general health information, your specific concern might require personalized medical advice.\n\n💡 Book with our pharmacists for:\n• Individual assessment\n• Personalized guidance\n• Specific medical questions\n• Treatment recommendations\n\n📅 Ready to book? Tap 'Book Appointment' below!\n\nNeed help with anything else?";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.smart_toy, color: Colors.green[700]),
            ),
            SizedBox(width: 12),
            Text(
              'Ask Ernest',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green[700]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          // Quick action buttons
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _navigateToAppointment,
                    icon: Icon(Icons.calendar_today,
                        size: 18, color: Colors.green[600]),
                    label: Text(
                      'Book Appointment',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.green[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Add a helpful tip
                      setState(() {
                        _messages.add(SimpleChatMessage(
                          text:
                              "💡 Quick Health Tips:\n\n• Stay hydrated (8 glasses of water daily)\n• Get 7-9 hours of sleep\n• Exercise for 30 minutes daily\n• Eat a balanced diet\n• Practice stress management\n\nNeed specific advice? Book an appointment with our pharmacists!",
                          isUser: false,
                          timestamp: DateTime.now(),
                        ));
                      });
                    },
                    icon: Icon(Icons.lightbulb_outline,
                        size: 18, color: Colors.orange[600]),
                    label: Text(
                      'Health Tips',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask Ernest anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(SimpleChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child:
                      Icon(Icons.smart_toy, size: 20, color: Colors.green[700]),
                ),
                SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser ? Colors.green[600] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (message.isUser) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          // Show Yes/No buttons if needed
          if (message.showYesNoButtons && !message.isUser) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(left: 40),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _handleYesResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          'Much Better! 😊',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _handleNoResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[500],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          'Still Need Help',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.smart_toy, size: 20, color: Colors.green[700]),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                SizedBox(width: 4),
                _buildTypingDot(1),
                SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.green[400],
        borderRadius: BorderRadius.circular(4),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 600),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.5 + (0.5 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// Simple chat message model
class SimpleChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool showYesNoButtons;

  SimpleChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.showYesNoButtons = false,
  });
}
