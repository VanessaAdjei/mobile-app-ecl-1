// pages/profile.dart

import 'dart:async';

import 'package:eclapp/pages/loggedout.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/providers/theme_provider.dart';
import 'package:eclapp/services/wishlist_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_error_utils.dart';
import '../utils/app_theme_colors.dart';
import 'bottomnav.dart';
import 'main_tab_shell.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../providers/cart_provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  ProfileState createState() => ProfileState();
}

class ProfileState extends State<Profile> with TickerProviderStateMixin {
  String _userName = "User";
  String _userEmail = "No email available";
  bool _userLoggedIn = false;
  late AnimationController _contentAnimationController;
  late Animation<double> _contentAnimation;
  final ScrollController _scrollController = ScrollController();
  int? _wishlistCount;
  String? _appVersion;

  @override
  void initState() {
    super.initState();

    // set up the animations
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutQuart,
    );

    unawaited(_loadAppVersion());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      _startAnimations();
    });
  }

  @override
  void dispose() {
    _contentAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentAnimationController.forward();
    });
  }

  Future<void> _initializeUserData() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      setState(() => _userLoggedIn = loggedIn);
      if (loggedIn) {
        await _loadUserData();
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorUtils.showSnack(
          context, 'Error loading profile: ${e.toString()}',
          isError: true);
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (e) {
      debugPrint('Profile: could not load app version: $e');
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      setState(() => _userLoggedIn = loggedIn);

      if (loggedIn) {
        await _loadUserData();
      }

      await _refreshWishlistCount();

      if (mounted) {
        await context.read<NotificationProvider>().refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userName = userData?['name'] ?? "User";
        _userEmail = userData?['email'] ?? "No email available";
      });
    } catch (e) {
      debugPrint('Error loading user data in profile: $e');
      if (!mounted) return;
      setState(() {
        _userName = "User";
        _userEmail = "No email available";
      });
    }
  }

  void _navigateTo(String routeName, {Map<String, dynamic>? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments).then((_) {
      if (routeName == AppRoutes.wishlist && mounted) {
        _refreshWishlistCount();
      }
    });
  }

  Future<void> _refreshWishlistCount() async {
    if (!mounted) return;
    try {
      final count =
          await WishlistService.instance.getWishlistCount(useCache: false);
      if (mounted) {
        setState(() {
          _wishlistCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing wishlist count: $e');
    }
  }

  void _navigateToRefillPage() {
    Navigator.pushNamed(context, AppRoutes.refill);
  }

  void _showLogoutDialog() {
    if (!mounted) return;

    // Store context reference before showing dialog
    final currentContext = context;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Confirm Logout",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to logout from your account?",
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () async {
                // get the providers before we do async stuff
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final cartProvider =
                    Provider.of<CartProvider>(context, listen: false);
                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                bool logoutSuccess = false;
                String? errorMsg;
                try {
                  debugPrint(' Starting logout process');
                  await AuthService.logout();
                  debugPrint(' AuthService.logout() completed');
                  try {
                    await authProvider.logout();
                    debugPrint('🔍 Profile: authProvider.logout() completed');
                  } catch (e) {
                    debugPrint('🔍 Profile: authProvider.logout() error: $e');
                    // ignore this error, we dont care
                  }
                  await cartProvider.handleUserLogout();
                  debugPrint(
                      '🔍 Profile: cartProvider.handleUserLogout() completed');
                  userProvider.clearUserData();
                  debugPrint(
                      '🔍 Profile: userProvider.clearUserData() completed');
                  logoutSuccess = true;
                  debugPrint('🔍 Profile: Logout successful');
                } catch (e) {
                  debugPrint('🔍 Profile: Logout error: $e');
                  errorMsg = 'Error during logout: ${e.toString()}';
                }
                if (!mounted) return;

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }

                await Future.delayed(Duration(milliseconds: 100));

                if (!mounted) return;

                if (logoutSuccess) {
                  debugPrint('🔍 Profile: Setting userLoggedIn to false');
                  setState(() {
                    _userLoggedIn = false;
                  });

                  if (mounted) {
                    debugPrint('🔍 Profile: Starting navigation delay');
                    await Future.delayed(Duration(milliseconds: 200));
                    if (mounted) {
                      debugPrint('🔍 Profile: Navigating to LoggedOutScreen');
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => LoggedOutScreen()),
                        (route) => false,
                      );
                      debugPrint('🔍 Profile: Navigation completed');
                    } else {
                      debugPrint('🔍 Profile: Widget not mounted after delay');
                    }
                  } else {
                    debugPrint('🔍 Profile: Widget not mounted before delay');
                  }
                } else if (errorMsg != null && mounted) {
                  AppErrorUtils.showSnack(context, errorMsg, isError: true);
                }
              },
              child: Text(
                "Logout",
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  // go to login page
  void _handleLogin() {
    Navigator.pushNamed(
      context,
      AppRoutes.signIn,
      arguments: {'returnTo': '/profile'},
    );
  }

  void _showSignInRequiredDialog(BuildContext context, {String? feature}) {
    final theme = context.appColors;
    final isDark = theme.isDark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primaryDark;
    final accentFill = isDark ? AppColors.primary : Colors.green.shade700;

    showDialog(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.border),
          ),
          backgroundColor: theme.sheetBg,
          surfaceTintColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              AppColors.primary.withValues(alpha: 0.85),
                              AppColors.primaryDark,
                            ]
                          : [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.green.shade200,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sign In Required',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  feature != null && feature.isNotEmpty
                      ? 'Sign in to access $feature.'
                      : 'This feature is only for signed up users.\nSign in to upload a prescription, get refillable drugs, and track your order.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.muted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(color: accent, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.pushNamed(
                            dialogContext,
                            AppRoutes.signIn,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentFill,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: isDark ? 0 : 4,
                          shadowColor: isDark
                              ? Colors.transparent
                              : Colors.green.shade200,
                        ),
                        child: Text(
                          'Sign In',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
    );
  }

  String get _avatarInitial {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'user') return 'G';
    return trimmed[0].toUpperCase();
  }

  void _requireSignIn({String? feature}) {
    _showSignInRequiredDialog(context, feature: feature);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = context.appColors;
    final isDark = themeProvider.isDarkMode;
    final bg = theme.pageBg;
    final surface = theme.surface;
    final ink = theme.ink;
    final muted = theme.muted;
    final border = theme.border;

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshProfile,
        child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          EclExpandableSliverAppBar(
            toolbarTitle: 'Profile',
            heroTitle: 'Profile',
            heroSubtitle: 'Manage your account and preferences',
            centerTitle: true,
            expandedTitleAlignment: Alignment.bottomCenter,
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                MainTabShell.goToTab(context, 0);
              }
            },
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CartIconButton(
                    iconColor: Colors.white,
                    iconSize: 22,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 24 * (1 - _contentAnimation.value)),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    _ProfileHeaderCard(
                      isDark: isDark,
                      loggedIn: _userLoggedIn,
                      name: _userName,
                      email: _userEmail,
                      initial: _avatarInitial,
                      onSignIn: _handleLogin,
                    ),
                    const SizedBox(height: 24),
                    _ProfileSection(
                      title: 'Preferences',
                      muted: muted,
                      child: _ProfileMenuGroup(
                        surface: surface,
                        border: border,
                        children: [
                          Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) {
                              return _ProfileSwitchTile(
                                icon: Icons.dark_mode_outlined,
                                iconColor: Colors.indigo.shade400,
                                title: 'Dark mode',
                                subtitle: themeProvider.isDarkMode
                                    ? 'On'
                                    : 'Off',
                                ink: ink,
                                muted: muted,
                                value: themeProvider.isDarkMode,
                                onChanged: (_) =>
                                    themeProvider.toggleTheme(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileSection(
                      title: 'Account',
                      muted: muted,
                      child: _ProfileMenuGroup(
                        surface: surface,
                        border: border,
                        children: [
                          _ProfileMenuTile(
                            icon: Icons.person_outline_rounded,
                            iconColor: AppColors.primary,
                            title: 'Profile information',
                            subtitle: 'Name, email & delivery addresses',
                            ink: ink,
                            muted: muted,
                            onTap: _userLoggedIn
                                ? () => _navigateTo(AppRoutes.profileScreen)
                                : () => _requireSignIn(
                                      feature: 'profile information',
                                    ),
                          ),
                          Selector<NotificationProvider, int>(
                            selector: (_, p) => p.unreadCount,
                            builder: (context, unread, _) {
                              return _ProfileMenuTile(
                                icon: Icons.notifications_outlined,
                                iconColor: Colors.orange.shade700,
                                title: 'Notifications',
                                subtitle: 'Alerts & order updates',
                                ink: ink,
                                muted: muted,
                                badge: unread > 0 ? unread : null,
                                badgeColor: Colors.orange.shade600,
                                onTap: _userLoggedIn
                                    ? () =>
                                        _navigateTo(AppRoutes.notifications)
                                    : () => _requireSignIn(
                                          feature: 'notifications',
                                        ),
                              );
                            },
                          ),
                          FutureBuilder<int>(
                            future: _wishlistCount != null
                                ? Future.value(_wishlistCount!)
                                : WishlistService.instance
                                    .getWishlistCount(useCache: false),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                _wishlistCount = snapshot.data;
                              }
                              final count =
                                  snapshot.data ?? _wishlistCount ?? 0;
                              return _ProfileMenuTile(
                                icon: Icons.favorite_outline_rounded,
                                iconColor: Colors.pink.shade400,
                                title: 'My wishlist',
                                subtitle: 'Saved products',
                                ink: ink,
                                muted: muted,
                                badge: count > 0 ? count : null,
                                badgeColor: AppColors.primary,
                                onTap: () => _navigateTo(AppRoutes.wishlist),
                              );
                            },
                          ),
                          _ProfileMenuTile(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: AppColors.primaryDark,
                            title: 'My wallet',
                            subtitle: 'Balance & transactions',
                            ink: ink,
                            muted: muted,
                            onTap: _userLoggedIn
                                ? () => _navigateTo(AppRoutes.wallet)
                                : () => _requireSignIn(feature: 'wallet'),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileSection(
                      title: 'Health & orders',
                      muted: muted,
                      child: _ProfileMenuGroup(
                        surface: surface,
                        border: border,
                        children: [
                          _ProfileMenuTile(
                            icon: Icons.upload_file_outlined,
                            iconColor: AppColors.primaryDark,
                            title: 'Uploaded prescriptions',
                            subtitle: 'Your prescription history',
                            ink: ink,
                            muted: muted,
                            onTap: _userLoggedIn
                                ? () =>
                                    _navigateTo(AppRoutes.prescriptionHistory)
                                : () => _requireSignIn(
                                      feature: 'uploaded prescriptions',
                                    ),
                          ),
                          _ProfileMenuTile(
                            icon: Icons.calendar_month_outlined,
                            iconColor: Colors.teal.shade700,
                            title: 'My appointments',
                            subtitle: 'Consultations & follow-ups',
                            ink: ink,
                            muted: muted,
                            onTap: _userLoggedIn
                                ? () => _navigateTo(AppRoutes.myAppointments)
                                : () => _requireSignIn(feature: 'appointments'),
                          ),
                          _ProfileMenuTile(
                            icon: Icons.refresh_rounded,
                            iconColor: AppColors.primary,
                            title: 'Refill medicines',
                            subtitle: 'Reorder your medications',
                            ink: ink,
                            muted: muted,
                            onTap: _userLoggedIn
                                ? _navigateToRefillPage
                                : () => _requireSignIn(
                                      feature: 'refill medicines',
                                    ),
                          ),
                          _ProfileMenuTile(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: AppColors.primaryDark,
                            title: 'Purchases',
                            subtitle: _userLoggedIn
                                ? 'Order history & tracking'
                                : 'Sign in to view orders',
                            ink: ink,
                            muted: muted,
                            onTap: _userLoggedIn
                                ? () => _navigateTo(AppRoutes.purchases)
                                : () => _requireSignIn(
                                      feature: 'order tracking and purchases',
                                    ),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileSection(
                      title: 'Support',
                      muted: muted,
                      child: _ProfileMenuGroup(
                        surface: surface,
                        border: border,
                        children: [
                          _ProfileMenuTile(
                            icon: Icons.description_outlined,
                            iconColor: muted,
                            title: 'Terms & conditions',
                            ink: ink,
                            muted: muted,
                            onTap: () =>
                                _navigateTo(AppRoutes.termsAndConditions),
                          ),
                          _ProfileMenuTile(
                            icon: Icons.privacy_tip_outlined,
                            iconColor: muted,
                            title: 'Privacy policy',
                            ink: ink,
                            muted: muted,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            ),
                          ),
                          _ProfileMenuTile(
                            icon: Icons.assignment_return_outlined,
                            iconColor: muted,
                            title: 'Return & refund policy',
                            ink: ink,
                            muted: muted,
                            onTap: () => _navigateTo(AppRoutes.returnPolicy),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_userLoggedIn)
                      _ProfilePrimaryButton(
                        label: 'Sign in',
                        icon: Icons.login_rounded,
                        onTap: _handleLogin,
                      )
                    else
                      _ProfileDestructiveButton(
                        label: 'Log out',
                        onTap: _showLogoutDialog,
                      ),
                    if (_appVersion != null) ...[
                      const SizedBox(height: 16),
                      _ProfileVersionFooter(version: _appVersion!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar:
          widget.showBottomNav ? const CustomBottomNav(selectedIndex: 4) : null,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.isDark,
    required this.loggedIn,
    required this.name,
    required this.email,
    required this.initial,
    required this.onSignIn,
  });

  final bool isDark;
  final bool loggedIn;
  final String name;
  final String email;
  final String initial;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        isDark ? Colors.green.shade400 : AppColors.primaryDark;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF334155)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF7FAFF), Color(0xFFEEF6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.12),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
              gradient: loggedIn
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    )
                  : null,
              color: loggedIn
                  ? null
                  : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
            alignment: Alignment.center,
            child: loggedIn
                ? Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.person, size: 48, color: primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
            loggedIn ? name : 'Guest User',
            textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
              color: ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
          if (loggedIn)
            Text(
              email,
              textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                color: muted,
                                  fontWeight: FontWeight.w400,
                                ),
                              )
          else ...[
            Text(
              'Sign in to sync orders across devices',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onSignIn,
                                child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                    color: primaryColor.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                      'Sign in to continue',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileVersionFooter extends StatelessWidget {
  const _ProfileVersionFooter({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Center(
                    child: Text(
        'Version $version',
                      style: GoogleFonts.poppins(
          fontSize: 11,
          color: context.appColors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProfileSwitchTile extends StatelessWidget {
  const _ProfileSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.muted,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color ink;
  final Color muted;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = context.appColors.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          // M3 on Android can render a near-white inactive switch on pale cards.
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor:
                isDark ? const Color(0xFF475569) : Colors.grey.shade600,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.muted,
    required this.child,
  });

  final String title;
  final Color muted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
            title.toUpperCase(),
                      style: GoogleFonts.poppins(
              fontSize: 11,
                        fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: muted,
                      ),
                    ),
                  ),
        child,
      ],
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({
    required this.surface,
    required this.border,
    required this.children,
  });

  final Color surface;
  final Color border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: border, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.ink,
    required this.muted,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color ink;
  final Color muted;
  final VoidCallback onTap;
  final int? badge;
  final Color? badgeColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                width: 36,
                height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                    ),
                child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                        fontSize: 14,
                            fontWeight: FontWeight.w600,
                        color: ink,
                          ),
                        ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                        subtitle!,
                            style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: muted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              if (badge != null && badge! > 0)
                        Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                    color: badgeColor ?? AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                    badge! > 99 ? '99+' : '$badge',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
              Icon(Icons.chevron_right_rounded, size: 20, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePrimaryButton extends StatelessWidget {
  const _ProfilePrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _ProfileDestructiveButton extends StatelessWidget {
  const _ProfileDestructiveButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
