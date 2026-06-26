// pages/profile.dart
import 'dart:async';
import 'package:eclapp/pages/loggedout.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/models/theme_preference.dart';
import 'package:eclapp/providers/theme_provider.dart';
import 'package:eclapp/services/wishlist_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/native_notification_service.dart';
import '../utils/app_error_utils.dart';
import '../utils/app_theme_colors.dart';
import 'bottomnav.dart';
import 'main_tab_shell.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/app_version.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/logout_confirm_dialog.dart';
import '../widgets/profile_page_tour.dart';
import '../widgets/profile_swipe_hint.dart';
import '../widgets/sign_in_required_dialog.dart';
import '../providers/cart_provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

const Color _kProfilePageBg = Color(0xFFF6F8FA);
const Color _kProfilePageBgMint = Color(0xFFEFFCF4);

class Profile extends StatefulWidget {
  const Profile({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  ProfileState createState() => ProfileState();
}

class _ProfileThemeSegmentTile extends StatelessWidget {
  const _ProfileThemeSegmentTile({
    required this.title,
    required this.choice,
    required this.ink,
    required this.muted,
    required this.fieldBg,
    required this.fieldBorder,
    required this.onSelect,
  });

  final String title;
  final AppThemeChoice choice;
  final Color ink;
  final Color muted;
  final Color fieldBg;
  final Color fieldBorder;
  final ValueChanged<AppThemeChoice> onSelect;

  static const _animDuration = Duration(milliseconds: 320);
  static const _animCurve = Curves.easeInOutCubicEmphasized;

  @override
  Widget build(BuildContext context) {
    final trackBg = context.appColors.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final isDark = choice == AppThemeChoice.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            height: 30,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: trackBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fieldBorder.withValues(alpha: 0.65)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pillWidth = constraints.maxWidth / 2;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: _animDuration,
                        curve: _animCurve,
                        left: isDark ? pillWidth : 0,
                        top: 0,
                        bottom: 0,
                        width: pillWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _segment(
                            label: 'Light',
                            icon: Icons.light_mode_outlined,
                            selected: !isDark,
                            ink: ink,
                            muted: muted,
                            onTap: () => _select(AppThemeChoice.light),
                          ),
                          _segment(
                            label: 'Dark',
                            icon: Icons.dark_mode_outlined,
                            selected: isDark,
                            ink: ink,
                            muted: muted,
                            onTap: () => _select(AppThemeChoice.dark),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _select(AppThemeChoice next) {
    if (choice == next) return;
    HapticFeedback.selectionClick();
    onSelect(next);
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    final selectedColor = Colors.white;
    final unselectedColor = ink.withValues(alpha: 0.72);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: SizedBox(
            height: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected ? selectedColor : muted,
                  ),
                  duration: _animDuration,
                  curve: _animCurve,
                  builder: (context, color, _) {
                    return Icon(icon, size: 13, color: color);
                  },
                ),
                const SizedBox(width: 3),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected ? selectedColor : unselectedColor,
                  ),
                  duration: _animDuration,
                  curve: _animCurve,
                  builder: (context, color, _) {
                    return Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCompactSwitchRow extends StatelessWidget {
  const _ProfileCompactSwitchRow({
    required this.title,
    required this.value,
    required this.ink,
    required this.fieldBg,
    required this.fieldBorder,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final Color ink;
  final Color fieldBg;
  final Color fieldBorder;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final trackOff = context.appColors.isDark
        ? const Color(0xFF475569)
        : Colors.grey.shade400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 5, 4, 5),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: fieldBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.68,
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: trackOff,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileState extends State<Profile> with WidgetsBindingObserver {
  String _userName = "User";
  String _userEmail = "No email available";
  bool _userLoggedIn = false;
  bool _pushNotificationsEnabled = false;
  final ScrollController _scrollController = ScrollController();
  int? _wishlistCount;
  final _swipeHint = ProfileSwipeHintController();
  final _tourHeaderKey = GlobalKey();
  final _tourPreferencesKey = GlobalKey();
  final _tourAccountKey = GlobalKey();
  final _tourHealthKey = GlobalKey();
  final _tourSupportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      unawaited(_syncPushNotifications());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPushNotificationStatus());
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final previous = _swipeHint.show;
    _swipeHint.update(_scrollController);
    if (previous != _swipeHint.show && mounted) {
      setState(() {});
    }
  }

  void _scheduleSwipeHintCheck() {
    scheduleProfileSwipeHintCheck(
      controller: _scrollController,
      hint: _swipeHint,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _runTourThenSwipeHint() async {
    if (!mounted) return;
    final tourShown = await ProfilePageTour.maybeStart(
      context: context,
      targets: ProfilePageTourTargets(
        headerKey: _tourHeaderKey,
        preferencesKey: _tourPreferencesKey,
        accountKey: _tourAccountKey,
        healthKey: _tourHealthKey,
        supportKey: _tourSupportKey,
      ),
      scrollController: _scrollController,
    );
    if (!mounted) return;
    if (tourShown) {
      _swipeHint.reset();
    }
    _scheduleSwipeHintCheck();
  }

  Future<void> _initializeUserData() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      setState(() => _userLoggedIn = loggedIn);
      if (loggedIn) {
        await _loadUserData();
      } else {
        await context.read<NotificationProvider>().clearForSignedOutUser();
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_runTourThenSwipeHint());
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorUtils.showSnack(context, 'Error loading profile: ${e.toString()}',
          isError: true);
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
      await _syncPushNotifications();

      if (mounted) {
        await context.read<NotificationProvider>().refreshUnreadCount();
      }
      _scheduleSwipeHintCheck();
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
  }

  Future<void> _syncPushNotifications() async {
    if (!mounted) return;
    await NativeNotificationService.syncPushNotificationsFromOnboarding(
      context: context,
    );
    await _refreshPushNotificationStatus();
  }

  Future<void> _refreshPushNotificationStatus() async {
    final enabled =
        await NativeNotificationService.resolvePushNotificationsEnabled();
    if (!mounted) return;
    setState(() => _pushNotificationsEnabled = enabled);
  }

  Future<void> _onPushNotificationToggle(bool enabled) async {
    if (enabled) {
      final granted =
          await NativeNotificationService.requestNotificationPermissionDirect(
        context: context,
      );
      if (granted) {
        await NativeNotificationService.setPushNotificationsOptIn(true);
      }
    } else {
      await NativeNotificationService.setPushNotificationsOptIn(false);
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            'Turn off notifications',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Notifications are managed in your device settings. '
            'Open Settings to disable alerts for this app.',
            style: GoogleFonts.poppins(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await openAppSettings();
      }
    }
    await _refreshPushNotificationStatus();
  }

  Future<void> _loadUserData() async {
    try {
      final userData =
          await AuthService.getCurrentUser(refreshFromServer: true);
      if (!mounted) return;
      setState(() {
        _userName =
            userData?['name'] ?? userData?['fname'] ?? 'User';
        _userEmail = userData?['email'] ?? 'No email available';
      });
    } catch (e) {
      debugPrint('Error loading user data in profile: $e');
      if (!mounted) return;
      setState(() {
        _userName = 'User';
        _userEmail = 'No email available';
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

    LogoutConfirmDialog.show(
      context,
      onConfirm: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
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
          }
          await cartProvider.handleUserLogout();
          debugPrint('🔍 Profile: cartProvider.handleUserLogout() completed');
          await context.read<NotificationProvider>().clearForSignedOutUser();
          userProvider.clearUserData();
          debugPrint('🔍 Profile: userProvider.clearUserData() completed');
          logoutSuccess = true;
          debugPrint('🔍 Profile: Logout successful');
        } catch (e) {
          debugPrint('🔍 Profile: Logout error: $e');
          errorMsg = 'Error during logout: ${e.toString()}';
        }
        if (!mounted) return;

        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;

        if (logoutSuccess) {
          setState(() => _userLoggedIn = false);
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoggedOutScreen()),
            (route) => false,
          );
        } else if (errorMsg != null) {
          AppErrorUtils.showSnack(context, errorMsg, isError: true);
        }
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

  void _requireSignIn({String? feature}) {
    SignInRequiredDialog.showAndNavigate(
      context,
      feature: feature,
      returnTo: AppRoutes.profile,
    );
  }

  String get _avatarInitial {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'user') return 'G';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final bg = theme.pageBg;
    final surface = theme.surface;
    final ink = theme.ink;
    final muted = theme.muted;
    final border = theme.border;

    return Scaffold(
      backgroundColor: bg,
      body: _profileHubBackdrop(
        context: context,
        child: Stack(
          children: [
            RefreshIndicator(
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
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        KeyedSubtree(
                          key: _tourHeaderKey,
                          child: _ProfileHeaderCard(
                            surface: surface,
                            loggedIn: _userLoggedIn,
                            name: _userName,
                            email: _userEmail,
                            initial: _avatarInitial,
                            ink: ink,
                            muted: muted,
                            onSignIn: _handleLogin,
                          ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _tourPreferencesKey,
                          child: _ProfileHubCard(
                          surface: surface,
                          border: border,
                          fieldBg: theme.fieldBg,
                          ink: ink,
                          muted: muted,
                          title: 'Preferences',
                          subtitle: 'Theme & notifications',
                          icon: Icons.tune_rounded,
                          iconTint: Colors.indigo.shade400,
                          children: [
                            Consumer<ThemeProvider>(
                              builder: (context, themeProvider, _) {
                                return _ProfileThemeSegmentTile(
                                  title: 'Appearance',
                                  choice: themeProvider.themeChoice,
                                  ink: ink,
                                  muted: muted,
                                  fieldBg: theme.fieldBg,
                                  fieldBorder: border,
                                  onSelect: themeProvider.setThemeChoice,
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            _ProfileCompactSwitchRow(
                              title: 'Push notifications',
                              value: _pushNotificationsEnabled,
                              ink: ink,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onChanged: (enabled) {
                                unawaited(_onPushNotificationToggle(enabled));
                              },
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _tourAccountKey,
                          child: _ProfileHubCard(
                          surface: surface,
                          border: border,
                          fieldBg: theme.fieldBg,
                          ink: ink,
                          muted: muted,
                          title: 'Account',
                          subtitle: 'Profile, wallet & saved items',
                          icon: Icons.person_outline_rounded,
                          iconTint: AppColors.primary,
                          children: [
                            _ProfileMenuTile(
                              icon: Icons.person_outline_rounded,
                              iconColor: AppColors.primary,
                              title: 'Profile information',
                              subtitle: 'Name, email & home address',
                              ink: ink,
                              muted: muted,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onTap: _userLoggedIn
                                  ? () => _navigateTo(AppRoutes.profileScreen)
                                  : () => _requireSignIn(
                                        feature: 'profile information',
                                      ),
                            ),
                            if (_userLoggedIn) ...[
                              const SizedBox(height: 6),
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
                                    fieldBg: theme.fieldBg,
                                    fieldBorder: border,
                                    badge: unread > 0 ? unread : null,
                                    badgeColor: Colors.orange.shade600,
                                    onTap: () =>
                                        _navigateTo(AppRoutes.notifications),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 6),
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
                                  fieldBg: theme.fieldBg,
                                  fieldBorder: border,
                                  badge: count > 0 ? count : null,
                                  badgeColor: AppColors.primary,
                                  onTap: () => _navigateTo(AppRoutes.wishlist),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            _ProfileMenuTile(
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: AppColors.primaryDark,
                              title: 'My wallet',
                              subtitle: 'Balance & transactions',
                              ink: ink,
                              muted: muted,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onTap: _userLoggedIn
                                  ? () => _navigateTo(AppRoutes.wallet)
                                  : () => _requireSignIn(feature: 'wallet'),
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _tourHealthKey,
                          child: _ProfileHubCard(
                          surface: surface,
                          border: border,
                          fieldBg: theme.fieldBg,
                          ink: ink,
                          muted: muted,
                          title: 'Health & orders',
                          subtitle: 'Prescriptions, bookings & purchases',
                          icon: Icons.medical_services_outlined,
                          iconTint: AppColors.primaryDark,
                          children: [
                            _ProfileMenuTile(
                              icon: Icons.upload_file_outlined,
                              iconColor: AppColors.primaryDark,
                              title: 'Uploaded prescriptions',
                              subtitle: 'Your prescription history',
                              ink: ink,
                              muted: muted,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onTap: _userLoggedIn
                                  ? () => _navigateTo(
                                        AppRoutes.prescriptionHistory,
                                      )
                                  : () => _requireSignIn(
                                        feature: 'uploaded prescriptions',
                                      ),
                            ),
                            const SizedBox(height: 6),
                            _ProfileMenuTile(
                              icon: Icons.calendar_month_outlined,
                              iconColor: Colors.teal.shade700,
                              title: 'My appointments',
                              subtitle: 'Consultations & follow-ups',
                              ink: ink,
                              muted: muted,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onTap: _userLoggedIn
                                  ? () => _navigateTo(AppRoutes.myAppointments)
                                  : () => _requireSignIn(
                                        feature: 'appointments',
                                      ),
                            ),
                            const SizedBox(height: 6),
                            _ProfileMenuTile(
                              icon: Icons.refresh_rounded,
                              iconColor: AppColors.primary,
                              title: 'Refill medicines',
                              subtitle: 'Reorder your medications',
                              ink: ink,
                              muted: muted,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onTap: _userLoggedIn
                                  ? _navigateToRefillPage
                                  : () => _requireSignIn(
                                        feature: 'refill medicines',
                                      ),
                            ),
                            const SizedBox(height: 6),
                            _ProfileMenuTile(
                              icon: Icons.shopping_bag_outlined,
                              iconColor: AppColors.primaryDark,
                              title: 'Purchases',
                              subtitle: _userLoggedIn
                                  ? 'Order history & tracking'
                                  : 'Sign in to view orders',
                              ink: ink,
                              muted: muted,
                              fieldBg: theme.fieldBg,
                              fieldBorder: border,
                              onTap: _userLoggedIn
                                  ? () => _navigateTo(AppRoutes.purchases)
                                  : () => _requireSignIn(
                                        feature: 'order tracking and purchases',
                                      ),
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _tourSupportKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileHubCard(
                                surface: surface,
                                border: border,
                                fieldBg: theme.fieldBg,
                                ink: ink,
                                muted: muted,
                                title: 'Support',
                                subtitle: 'Policies and legal information',
                                icon: Icons.help_outline_rounded,
                                iconTint: muted,
                                children: [
                                  _ProfileMenuTile(
                                    icon: Icons.description_outlined,
                                    iconColor: muted,
                                    title: 'Terms & conditions',
                                    ink: ink,
                                    muted: muted,
                                    fieldBg: theme.fieldBg,
                                    fieldBorder: border,
                                    onTap: () => _navigateTo(
                                      AppRoutes.termsAndConditions,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _ProfileMenuTile(
                                    icon: Icons.privacy_tip_outlined,
                                    iconColor: muted,
                                    title: 'Privacy Statement',
                                    ink: ink,
                                    muted: muted,
                                    fieldBg: theme.fieldBg,
                                    fieldBorder: border,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PrivacyPolicyScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _ProfileMenuTile(
                                    icon: Icons.assignment_return_outlined,
                                    iconColor: muted,
                                    title: 'Return & refund policy',
                                    ink: ink,
                                    muted: muted,
                                    fieldBg: theme.fieldBg,
                                    fieldBorder: border,
                                    onTap: () =>
                                        _navigateTo(AppRoutes.returnPolicy),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _ProfileVersionFooter(
                            version: AppVersion.display),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            if (_swipeHint.show)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ProfileSwipeHint(
                  fadeColor: bg,
                  mutedColor: muted,
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

Widget _profileHubBackdrop({
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
                _kProfilePageBgMint,
                _kProfilePageBg,
                _kProfilePageBg,
              ],
        stops: const [0.0, 0.28, 1.0],
      ),
    ),
    child: child,
  );
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.surface,
    required this.loggedIn,
    required this.name,
    required this.email,
    required this.initial,
    required this.ink,
    required this.muted,
    required this.onSignIn,
  });

  final Color surface;
  final bool loggedIn;
  final String name;
  final String email;
  final String initial;
  final Color ink;
  final Color muted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: loggedIn
                          ? const LinearGradient(
                              colors: [
                                AppColors.primaryLight,
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            )
                          : null,
                      color: loggedIn
                          ? null
                          : AppColors.primary.withValues(alpha: 0.1),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: surface,
                      ),
                      alignment: Alignment.center,
                      child: loggedIn
                          ? Text(
                              initial,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            )
                          : const Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loggedIn ? name : 'Guest',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          loggedIn
                              ? email
                              : 'Sign in to sync orders and saved details',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: muted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!loggedIn)
                    TextButton(
                      onPressed: onSignIn,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Sign in',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
}

class _ProfileHubCard extends StatelessWidget {
  const _ProfileHubCard({
    required this.surface,
    required this.border,
    required this.fieldBg,
    required this.ink,
    required this.muted,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconTint,
    required this.children,
  });

  final Color surface;
  final Color border;
  final Color fieldBg;
  final Color ink;
  final Color muted;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconTint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconTint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: iconTint, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...children,
                ],
              ),
            ),
          ],
        ),
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

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.ink,
    required this.muted,
    required this.fieldBg,
    required this.fieldBorder,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color ink;
  final Color muted;
  final Color fieldBg;
  final Color fieldBorder;
  final VoidCallback onTap;
  final int? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
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
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppColors.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    badge! > 99 ? '99+' : '$badge',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, size: 18, color: muted),
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
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
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
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
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
