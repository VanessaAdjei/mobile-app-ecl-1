// widgets/smart_tips.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/pharmacists.dart';
import '../pages/wallet_page.dart';

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
  int _tipIndex = 0;

  List<TipData> get _tips => [
        TipData(
          id: 'search_tip',
          message:
              '🔍 Pro tip: Search for "paracetamol" or "vitamins" to find products instantly!',
          icon: Icons.search,
          color: Colors.blue,
          condition: TipCondition.always,
          hasAction: false,
        ),
        TipData(
          id: 'pharmacist_tip',
          message:
              '👨‍⚕️ Need health advice? Chat with our licensed pharmacists 24/7!',
          icon: Icons.medical_services,
          color: Colors.teal,
          condition: TipCondition.always,
          hasAction: true,
          actionText: 'Chat Now',
          onAction: _handlePharmacistAction,
        ),
        TipData(
          id: 'delivery_tip',
          message:
              '🚚 Fast delivery available! Choose pickup or home delivery.',
          icon: Icons.local_shipping,
          color: Colors.orange,
          condition: TipCondition.always,
          hasAction: false,
        ),
        TipData(
          id: 'safety_tip',
          message:
              '⚠️ Always consult your doctor before trying new medications.',
          icon: Icons.warning,
          color: Colors.red,
          condition: TipCondition.always,
          hasAction: false,
        ),
        TipData(
          id: 'welcome_tip',
          message:
              '🎉 Welcome to ECL! Your digital wallet is ready with your personal e-card.',
          icon: Icons.credit_card,
          color: Colors.green,
          condition: TipCondition.always,
          hasAction: true,
          actionText: 'View Wallet',
          onAction: _handleWalletAction,
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
      setState(() {
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

  void _handleTipAction(TipData tip) {
    debugPrint('🔍 SmartTips: Action triggered for tip: ${tip.id}');

    // Add haptic feedback
    // HapticFeedback.lightImpact();

    // Execute the action
    if (tip.onAction != null) {
      tip.onAction!();
    }

    // Auto-advance to next tip after action
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && _tipIndex < _tips.length - 1) {
        _pageController?.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Action handlers for each tip

  void _handlePharmacistAction() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PharmacistsPage(),
      ),
    );
  }

  void _handleDeliveryAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚚 Delivery options available!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleSafetyAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ Safety guidelines displayed!'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleWalletAction() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletPage(),
      ),
    );
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
            height: 240, // Reduced to make it more compact
            padding: const EdgeInsets.all(12), // Reduced from 14 to 12
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lightbulb,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Welcome Tips',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _closeTips,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
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
                      return GestureDetector(
                        onTap: () {
                          // Make the entire tip card clickable for better UX
                          if (tip.hasAction && tip.onAction != null) {
                            _handleTipAction(tip);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tip.color.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tip content
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      tip.color.withOpacity(0.1),
                                      tip.color.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tip.color.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  tip.icon,
                                  color: tip.color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 4), // Reduced from 6
                              Text(
                                tip.message,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[800],
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              // Interactive action button
                              if (tip.hasAction &&
                                  tip.actionText != null &&
                                  tip.onAction != null)
                                GestureDetector(
                                  onTap: () => _handleTipAction(tip),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          tip.color,
                                          tip.color.withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: tip.color.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.touch_app,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          tip.actionText!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // Progress indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          tip.color.withOpacity(0.1),
                                          tip.color.withOpacity(0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: tip.color.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${index + 1} of ${_tips.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: tip.color,
                                        fontWeight: FontWeight.w600,
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
                                            duration: const Duration(
                                                milliseconds: 300),
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
                                          vertical: 6,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              tip.color.withOpacity(0.15),
                                              tip.color.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: tip.color.withOpacity(0.4),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: tip.color.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            index == _tips.length - 1
                                                ? 'Got it!'
                                                : 'Next',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
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
                                          vertical: 6,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: index == _tips.length - 1
                                                ? [
                                                    tip.color.withOpacity(0.15),
                                                    tip.color.withOpacity(0.1),
                                                  ]
                                                : [
                                                    Colors.grey
                                                        .withOpacity(0.1),
                                                    Colors.grey
                                                        .withOpacity(0.05),
                                                  ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: index == _tips.length - 1
                                                ? tip.color.withOpacity(0.4)
                                                : Colors.grey.withOpacity(0.3),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (index == _tips.length - 1
                                                      ? tip.color
                                                      : Colors.grey)
                                                  .withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            index == _tips.length - 1
                                                ? 'Complete'
                                                : 'Skip All',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
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
  final String? actionText;
  final VoidCallback? onAction;
  final bool hasAction;

  TipData({
    required this.id,
    required this.message,
    required this.icon,
    required this.color,
    required this.condition,
    this.actionText,
    this.onAction,
    this.hasAction = false,
  });
}

enum TipCondition {
  always,
  emptyCart,
  hasItems,
  firstVisit,
}
