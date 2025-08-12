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
  AnimationController? _slideController;
  AnimationController? _fadeController;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _fadeAnimation;
  PageController? _pageController;

  bool _isVisible = false;
  String _currentTip = '';
  int _tipIndex = 0;

  final List<TipData> _tips = [
    TipData(
      id: 'search_tip',
      message:
          '🔍 Try searching for "paracetamol" or "e-panol" to find products quickly!',
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
    _slideController?.dispose();
    _fadeController?.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure animations are properly initialized
    if ((_slideController?.isAnimating ?? false) ||
        (_fadeController?.isAnimating ?? false)) {
      return;
    }
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Dispose existing controllers if they exist
    _slideController?.dispose();
    _fadeController?.dispose();
    _pageController?.dispose();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pageController = PageController(initialPage: 0);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _checkAndShowTip() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTips = prefs.getBool('has_seen_smart_tips') ?? false;

    debugPrint(
        '🔍 SmartTips: Checking if tips should be shown. Has seen tips: $hasSeenTips');

    if (!hasSeenTips && mounted) {
      debugPrint('🔍 SmartTips: Tips not seen before, showing first tip');
      _showNextTip();
    } else if (hasSeenTips) {
      debugPrint('🔍 SmartTips: Tips already seen, not showing');
      setState(() {
        _isVisible = false;
      });
    }
  }

  void _showNextTip() {
    if (_tipIndex < _tips.length && mounted) {
      final tip = _tips[_tipIndex];

      setState(() {
        _currentTip = tip.message;
        _isVisible = true;
      });

      // Reset animations before starting new ones
      _fadeController?.reset();
      _slideController?.reset();

      _fadeController?.forward();
      _slideController?.forward();
    }
  }

  void _hideTip() {
    if (!mounted) return;

    _fadeController?.reverse();
    if (_slideController != null) {
      _slideController!.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    } else {
      // If controller is null, just hide immediately
      setState(() {
        _isVisible = false;
      });
    }
  }

  Future<void> _markTipsAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_smart_tips', true);
    debugPrint('🔍 SmartTips: Tips marked as seen, will not show again');
  }

  void _skipAllTips() {
    debugPrint('🔍 SmartTips: Skip all tips pressed');
    _hideTip();
    _tipIndex = _tips.length; // Skip to end
    _pageController?.jumpToPage(0); // Reset to first page
    _markTipsAsSeen();
  }

  void _completeAllTips() {
    debugPrint('🔍 SmartTips: Complete all tips pressed');
    _hideTip();
    _tipIndex = _tips.length; // Mark as complete
    _pageController?.jumpToPage(0); // Reset to first page
    _markTipsAsSeen();
  }

  void _closeTips() {
    debugPrint('🔍 SmartTips: Close button pressed');
    _hideTip();
    _markTipsAsSeen();
  }

  // Method to reset tips for testing (can be removed in production)
  static Future<void> resetTips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_smart_tips', false);
    debugPrint('🔍 SmartTips: Tips reset for testing');
  }

  @override
  Widget build(BuildContext context) {
    // Don't show tips if they've already been seen
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 200, // Position further down to avoid header elements
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
        child: FadeTransition(
          opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
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
                      onPressed: _closeTips,
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Close tips',
                    ),
                  ],
                ),
                const SizedBox(height: 6), // Reduced from 8
                // PageView for tips
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _tips.length,
                    onPageChanged: (index) {
                      debugPrint('🔍 SmartTips: Page changed to index $index');
                      setState(() {
                        _tipIndex = index;
                      });
                      debugPrint(
                          '🔍 SmartTips: Updated _tipIndex to $_tipIndex');
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
                                      debugPrint(
                                          '🔍 SmartTips: Next button tapped at index $index');
                                      if (index < _tips.length - 1) {
                                        // Navigate to next page
                                        debugPrint(
                                            '🔍 SmartTips: Navigating to next page');
                                        _pageController?.nextPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                        // Update tip index to match the new page
                                        setState(() {
                                          _tipIndex = index + 1;
                                        });
                                        debugPrint(
                                            '🔍 SmartTips: Updated tip index to $_tipIndex');
                                      } else {
                                        // Last tip - complete all tips
                                        debugPrint(
                                            '🔍 SmartTips: Last tip reached, completing all tips');
                                        _completeAllTips();
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
                                    onTap: index == _tips.length - 1
                                        ? () {
                                            debugPrint(
                                                '🔍 SmartTips: Complete button tapped');
                                            _completeAllTips();
                                          }
                                        : () {
                                            debugPrint(
                                                '🔍 SmartTips: Skip All button tapped');
                                            _skipAllTips();
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4, // Reduced from 6
                                      ),
                                      decoration: BoxDecoration(
                                        color: index == _tips.length - 1
                                            ? tip.color.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                            4), // Reduced from 6
                                        border: Border.all(
                                          color: index == _tips.length - 1
                                              ? tip.color.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          index == _tips.length - 1
                                              ? 'Complete'
                                              : 'Skip All',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10, // Reduced from 11
                                            fontWeight: FontWeight.w500,
                                            color: index == _tips.length - 1
                                                ? tip.color
                                                : Colors.grey[600],
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
