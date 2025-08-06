// pages/pharmacists.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_back_button.dart';
import '../widgets/cart_icon_button.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/health_tips_service.dart';
import '../models/health_tip.dart';
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
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _phoneFieldKey = GlobalKey();
  final GlobalKey _emailFieldKey = GlobalKey();
  final GlobalKey _symptomsFieldKey = GlobalKey();

  String _selectedConsultationType = 'WhatsApp';
  String _selectedGenderPreference = 'No Preference';
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _consultationTypes = [
    'WhatsApp',
    'Zoom',
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

  // Local cache for health tips
  static List<HealthTip> _cachedHealthTips = [];
  static DateTime? _lastHealthTipsCacheTime;
  static const Duration _healthTipsCacheExpiration = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _isLoadingHealthTips = true;
    });


    final backgroundTips = HealthTipsService.getCurrentTips(limit: 4);
    if (backgroundTips.isNotEmpty) {
      setState(() {
        _healthTips = backgroundTips;
        _isLoadingHealthTips = false;
      });
      debugPrint('PharmacistsPage: Using background service cached tips');
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
    // Show instant feedback
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
  }

  Future<void> _loadFreshHealthTipsInBackground() async {
    try {
      final backgroundTips = HealthTipsService.getCurrentTips(limit: 4);
      if (backgroundTips.isNotEmpty) {
        setState(() {
          _healthTips = backgroundTips;
          _isLoadingHealthTips = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Health insights updated'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final tips = await HealthTipsService.fetchHealthTips(limit: 4)
          .timeout(Duration(seconds: 6));

      if (mounted && tips.isNotEmpty) {
        // Cache the fresh tips locally
        _cachedHealthTips = tips;
        _lastHealthTipsCacheTime = DateTime.now();

        setState(() {
          _healthTips = tips;
          _isLoadingHealthTips = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Health insights updated'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 2),
          ),
        );
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

              // Show success message
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
            SizedBox(height: 12),
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
        setState(() {
          // Prefill name if available
          if (userData['name'] != null &&
              userData['name'].toString().isNotEmpty) {
            _nameController.text = userData['name'].toString();
          }

          // Prefill phone if available
          if (userData['phone'] != null &&
              userData['phone'].toString().isNotEmpty) {
            _phoneController.text = userData['phone'].toString();
          }

          // Prefill email if available
          if (userData['email'] != null &&
              userData['email'].toString().isNotEmpty) {
            _emailController.text = userData['email'].toString();
          }
        });

        // Show a subtle notification that fields were prefilled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Form prefilled with your profile data'),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Silently handle errors - form will remain empty if user data can't be loaded
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
              // Handle bar
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

              // Header
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
                      // Title
                      Text(
                        tip.title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 16),

                      // Image if available
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

                      // Content
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

                      // Action buttons
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

  void _showBookingForm() {
    // Check if user is logged in
    if (!_isUserLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
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
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Enhanced Handle bar with animation
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
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),

                // Enhanced Header with animations
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[600]!,
                        Colors.green[700]!,
                        Colors.green[800]!
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 26,
                        ),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book Virtual Consultation',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideX(begin: 0.3),
                            SizedBox(height: 4),
                            Text(
                              'Get expert advice from our pharmacists',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.95),
                                height: 1.2,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 400.ms)
                                .slideX(begin: 0.3),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close, color: Colors.white, size: 22),
                          tooltip: 'Close',
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.elasticOut),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),

                // Enhanced Form content with animations
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Progress indicator
                          _buildProgressIndicator(),
                          SizedBox(height: 24),

                          // Form fields with staggered animations
                          _buildModernDropdownField(
                            'Consultation Type',
                            _selectedConsultationType,
                            _consultationTypes,
                            (value) => setState(
                                () => _selectedConsultationType = value!),
                            Icons.video_call,
                          ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernDropdownField(
                            'Pharmacist Gender Preference',
                            _selectedGenderPreference,
                            _genderPreferences,
                            (value) => setState(
                                () => _selectedGenderPreference = value!),
                            Icons.person,
                          ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernTextField(
                            'Full Name',
                            _nameController,
                            Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            fieldKey: _nameFieldKey,
                          ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernTextField(
                            'Phone Number',
                            _phoneController,
                            Icons.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(value)) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                            fieldKey: _phoneFieldKey,
                          ).animate().fadeIn(delay: 900.ms).slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernTextField(
                            'Email Address',
                            _emailController,
                            Icons.email,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email address';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            fieldKey: _emailFieldKey,
                          ).animate().fadeIn(delay: 950.ms).slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernTextField(
                            'Symptoms/Concerns',
                            _symptomsController,
                            Icons.medical_services,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please describe your symptoms or concerns';
                              }
                              return null;
                            },
                            fieldKey: _symptomsFieldKey,
                          ).animate().fadeIn(delay: 1000.ms).slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernDatePicker()
                              .animate()
                              .fadeIn(delay: 1100.ms)
                              .slideX(begin: 0.2),
                          SizedBox(height: 20),

                          _buildModernTimePicker()
                              .animate()
                              .fadeIn(delay: 1200.ms)
                              .slideX(begin: 0.2),
                          SizedBox(height: 30),

                          // Enhanced submit button with loading state
                          _buildEnhancedSubmitButton(),
                          SizedBox(height: 20),
                        ],
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
    ).animate().fadeIn(delay: 1300.ms).scale(begin: Offset(0.8, 0.8));
  }

  void _submitBookingWithValidation() async {
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        centerTitle: Theme.of(context).appBarTheme.centerTitle,
        leading: AppBackButton(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          showConfirmation: true,
          confirmationTitle: 'Leave Pharmacists',
          confirmationMessage:
              'Are you sure you want to leave the pharmacists page?',
        ),
        title: Text(
          'Meet the Pharmacists',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          CartIconButton(
            iconColor: Colors.white,
            iconSize: 24,
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // My Booked Appointments Section
            if (_bookings.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Booked Appointments',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    if (_bookings.length > 1)
                      TextButton(
                        onPressed: () {
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
                        child: Text('See All'),
                      ),
                    TextButton(
                      onPressed: _clearBookings,
                      child: Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              _isUserLoggedIn
                  ? _buildBookingCard(_bookings.first)
                  : _buildLoginPromptCard(),
            ],
            // Main Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  // Hero Section
                  _buildHeroSection(),
                  SizedBox(height: 20),
                  // Virtual Consultation Section
                  _buildModernSectionHeader('Virtual Consultation',
                      Icons.video_call, 'Book your consultation'),
                  SizedBox(height: 12),
                  _buildModernVirtualConsultationCard(),
                  SizedBox(height: 20),
                  // Health Blogs Section
                  _buildModernSectionHeaderWithRefresh(
                      'Health Insights',
                      Icons.article,
                      'Latest health articles',
                      _refreshHealthTips),
                  SizedBox(height: 12),
                  _buildModernHealthBlogsSection(),
                  SizedBox(height: 100), // Space for chat button
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo[600]!,
            Colors.indigo[700]!,
            Colors.indigo[800]!
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.medical_services,
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
                      'Professional Healthcare',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get expert advice from our experienced pharmacists with 24/7 support.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.95),
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
                  Icons.check_circle, 'Expert Advice', Colors.green[400]!),
              _buildFeatureBadge(
                  Icons.access_time, '24/7 Support', Colors.orange[400]!),
              _buildFeatureBadge(
                  Icons.security, 'Secure & Private', Colors.blue[400]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionHeader(
      String title, IconData icon, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
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
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
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

  Widget _buildModernVirtualConsultationCard() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[500]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.15),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.video_call, color: Colors.white, size: 14),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Virtual Consultation',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Choose platform',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[600],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildModernPlatformSelection(),
          SizedBox(height: 8),
          _isUserLoggedIn
              ? _buildGradientButton(
                  'Book Now',
                  Icons.calendar_today,
                  _showBookingForm,
                )
              : _buildLoginRequiredButton(),
        ],
      ),
    );
  }

  Widget _buildModernPlatformSelection() {
    return Column(
      children: [
        _buildModernPlatformOption(
          'WhatsApp',
          FontAwesomeIcons.whatsapp,
          Colors.green,
          'Quick messaging',
          _selectedConsultationType == 'WhatsApp',
          () => setState(() => _selectedConsultationType = 'WhatsApp'),
        ),
        SizedBox(height: 8),
        _buildModernPlatformOption(
          'Zoom',
          Icons.video_call,
          Colors.blue,
          'Video consultation',
          _selectedConsultationType == 'Zoom',
          () => setState(() => _selectedConsultationType = 'Zoom'),
        ),
        SizedBox(height: 8),
        _buildModernPlatformOption(
          'Phone Call',
          Icons.call,
          const Color.fromARGB(255, 180, 97, 167),
          'Voice consultation',
          _selectedConsultationType == 'Phone Call',
          () => setState(() => _selectedConsultationType = 'Phone Call'),
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

  Widget _buildModernHealthBlogsSection() {
    if (_isLoadingHealthTips) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Updating health insights...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_healthTips.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.health_and_safety,
                size: 48,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No health insights available',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children:
          _healthTips.map((tip) => _buildModernHealthTipCard(tip)).toList(),
    );
  }

  Widget _buildModernHealthTipCard(HealthTip tip) {
    // Get appropriate icon and color based on category
    IconData icon;
    Color color;

    switch (tip.category.toLowerCase()) {
      case 'nutrition':
      case 'diet':
        icon = Icons.restaurant;
        color = Colors.orange;
        break;
      case 'exercise':
      case 'physical activity':
        icon = Icons.fitness_center;
        color = Colors.blue;
        break;
      case 'mental health':
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      case 'prevention':
        icon = Icons.shield;
        color = Colors.green;
        break;
      case 'wellness':
        icon = Icons.health_and_safety;
        color = Colors.teal;
        break;
      case 'heart health':
      case 'cardiovascular':
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case 'diabetes':
        icon = Icons.monitor_heart;
        color = Colors.orange;
        break;
      case 'pregnancy':
      case 'women\'s health':
        icon = Icons.pregnant_woman;
        color = Colors.pink;
        break;
      default:
        icon = Icons.health_and_safety;
        color = Colors.green;
    }

    return InkWell(
      onTap: tip.url.isNotEmpty ? () => _showHealthTipDetails(tip) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image or Icon container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: tip.imageUrl != null && tip.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: Image.network(
                        tip.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: 32,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
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
                                    AlwaysStoppedAnimation<Color>(color),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Icon(
                      icon,
                      color: color,
                      size: 32,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tip.category,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      tip.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      tip.summary ?? tip.content,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tip.url.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: color,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Learn more',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
