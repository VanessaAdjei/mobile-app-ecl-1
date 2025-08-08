// widgets/smart_tips.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartTips extends StatefulWidget {
  const SmartTips({super.key});

  @override
  State<SmartTips> createState() => _SmartTipsState();
}

class _SmartTipsState extends State<SmartTips> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isVisible = false;
  String _currentTip = '';
  int _tipIndex = 0;

  final List<TipData> _tips = [
    TipData(
      id: 'search_tip',
      message:
          '🔍 Try searching for "paracetamol" or "vitamins" to find products quickly!',
      icon: Icons.search,
      color: Colors.blue,
      condition: TipCondition.always,
    ),
    TipData(
      id: 'cart_tip',
      message: '🛒 Your cart is empty. Add some products to get started!',
      icon: Icons.shopping_cart,
      color: Colors.orange,
      condition: TipCondition.emptyCart,
    ),
    TipData(
      id: 'pharmacist_tip',
      message: '👨‍⚕️ Need advice? Our pharmacists are here to help!',
      icon: Icons.medical_services,
      color: Colors.green,
      condition: TipCondition.always,
    ),
    TipData(
      id: 'location_tip',
      message: '📍 Find the nearest ECL store for pickup or delivery!',
      icon: Icons.location_on,
      color: Colors.red,
      condition: TipCondition.always,
    ),
    TipData(
      id: 'categories_tip',
      message: '📦 Browse categories to discover new products!',
      icon: Icons.category,
      color: Colors.purple,
      condition: TipCondition.always,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAndShowTip();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _checkAndShowTip() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTips = prefs.getBool('has_seen_smart_tips') ?? false;

    if (!hasSeenTips && mounted) {
      _showNextTip();
    }
  }

  void _showNextTip() {
    if (_tipIndex < _tips.length) {
      final tip = _tips[_tipIndex];

      setState(() {
        _currentTip = tip.message;
        _isVisible = true;
      });

      _fadeController.forward();
      _slideController.forward();
    }
  }

  void _hideTip() {
    _fadeController.reverse();
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });

        // Show next tip after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _tipIndex++;
            if (_tipIndex < _tips.length) {
              _showNextTip();
            } else {
              _markTipsAsSeen();
            }
          }
        });
      }
    });
  }

  Future<void> _markTipsAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_smart_tips', true);
  }

  void _skipAllTips() {
    _hideTip();
    _tipIndex = _tips.length; // Skip to end
    _markTipsAsSeen();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 200, // Position further down to avoid header elements
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            height: 200, // Reduced from 220 to 200
            padding: const EdgeInsets.all(12), // Reduced from 14 to 12
            decoration: BoxDecoration(
              color: Colors.white, // Solid white background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Prevent overflow
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '💡 Smart Tips',
                      style: GoogleFonts.poppins(
                        fontSize: 14, // Increased from 13
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      onPressed: _skipAllTips,
                      icon: const Icon(Icons.close,
                          size: 18), // Increased from 16
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6), // Reduced from 8
                // PageView for tips
                Expanded(
                  child: PageView.builder(
                    itemCount: _tips.length,
                    onPageChanged: (index) {
                      setState(() {
                        _tipIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final tip = _tips[index];
                      return Container(
                        padding: const EdgeInsets.all(6), // Reduced from 8
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tip content
                            Container(
                              padding:
                                  const EdgeInsets.all(4), // Reduced from 6
                              decoration: BoxDecoration(
                                color: tip.color.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(4), // Reduced from 6
                              ),
                              child: Icon(
                                tip.icon,
                                color: tip.color,
                                size: 16, // Reduced from 18
                              ),
                            ),
                            const SizedBox(height: 4), // Reduced from 6
                            Text(
                              tip.message,
                              style: GoogleFonts.poppins(
                                fontSize: 10, // Reduced from 11
                                color: Colors.grey[700],
                                height: 1.1, // Reduced from 1.2
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4), // Reduced from 6
                            // Progress indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3, // Reduced from 4
                                    vertical: 1, // Reduced from 2
                                  ),
                                  decoration: BoxDecoration(
                                    color: tip.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                        4), // Reduced from 6
                                    border: Border.all(
                                      color: tip.color.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Tip ${index + 1} of ${_tips.length}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8, // Reduced from 9
                                      color: tip.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4), // Reduced from 6
                            // Navigation buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (index < _tips.length - 1) {
                                        setState(() {
                                          _tipIndex = index + 1;
                                        });
                                      } else {
                                        _skipAllTips();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4, // Reduced from 6
                                      ),
                                      decoration: BoxDecoration(
                                        color: tip.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                            4), // Reduced from 6
                                        border: Border.all(
                                          color: tip.color.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          index == _tips.length - 1
                                              ? 'Got it!'
                                              : 'Next',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10, // Reduced from 11
                                            fontWeight: FontWeight.w500,
                                            color: tip.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4), // Reduced from 6
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _skipAllTips,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4, // Reduced from 6
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                            4), // Reduced from 6
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Skip All',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10, // Reduced from 11
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
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
                      );
                    },
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

class TipData {
  final String id;
  final String message;
  final IconData icon;
  final Color color;
  final TipCondition condition;

  TipData({
    required this.id,
    required this.message,
    required this.icon,
    required this.color,
    required this.condition,
  });
}

enum TipCondition {
  always,
  emptyCart,
  hasItems,
  firstVisit,
}
