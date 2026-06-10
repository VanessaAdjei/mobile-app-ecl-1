// pages/profilescreen.dart
import 'package:eclapp/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import 'bottomnav.dart';
import 'homepage.dart';
import 'loggedout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String _userName = "User";
  String _userEmail = "No email available";
  String _phoneNumber = "";
  String? _deliveryAddressPreview;
  bool _loadingDeliveryAddress = true;

  static const Color _bodyTextLight = Color(0xFF374151);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    await Future.wait([
      _loadUserData(),
      _loadDeliveryAddressPreview(),
    ]);
  }

  Future<void> _loadDeliveryAddressPreview() async {
    if (!mounted) return;
    setState(() => _loadingDeliveryAddress = true);
    try {
      final result = await DeliveryService.getLastDeliveryInfo();
      if (!mounted) return;

      String? preview;
      if (result['success'] == true && result['data'] != null) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        preview = _formatDeliveryPreview(data);
      }

      setState(() {
        _deliveryAddressPreview = preview;
        _loadingDeliveryAddress = false;
      });
    } catch (e) {
      debugPrint('ProfileScreen: delivery address load failed: $e');
      if (!mounted) return;
      setState(() {
        _deliveryAddressPreview = null;
        _loadingDeliveryAddress = false;
      });
    }
  }

  static String? _formatDeliveryPreview(Map<String, dynamic> data) {
    final option =
        (data['delivery_option'] ?? data['shipping_type'] ?? 'delivery')
            .toString()
            .toLowerCase();

    if (option == 'pickup') {
      final pickup = [
        data['pickup_site'],
        data['pickup_location'],
        data['pickup_city'],
        data['pickup_region'],
      ]
          .map((v) => v?.toString().trim() ?? '')
          .where((v) => v.isNotEmpty)
          .toList();
      if (pickup.isNotEmpty) return 'Pickup · ${pickup.join(', ')}';
      return 'Pickup location saved';
    }

    final parts = [
      data['address'],
      data['city'],
      data['region'],
    ]
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return null;
  }

  void _openDeliveryAddresses() {
    Navigator.pushNamed(context, AppRoutes.delivery).then((_) {
      if (mounted) _loadDeliveryAddressPreview();
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userName = userData?['name'] ?? "User";
        _userEmail = userData?['email'] ?? "No email available";
        _phoneNumber = userData?['phone'] ?? "";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = "User";
        _userEmail = "No email available";
        _phoneNumber = "";
      });
    }
  }

  void _showLogoutDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Confirm Logout",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to logout from your account?",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage()),
                  );
                }
              },
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await AuthService.logout();
                if (mounted) {
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoggedOutScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                "Logout",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = context.appColors;
    final isDark = themeProvider.isDarkMode;

    final pageBg = theme.pageBg;
    final cardColor = theme.surface;
    final titleColor = theme.ink;
    final subtitleColor = isDark ? Colors.white60 : _bodyTextLight;
    final mutedColor = theme.muted;
    final fieldBg = theme.fieldBg;
    final fieldBorder = theme.border;

    return Scaffold(
      backgroundColor: pageBg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProfileData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            EclExpandableSliverAppBar(
              toolbarTitle: 'Profile',
              heroTitle: 'Your profile',
              heroSubtitle: 'Account details we have on file',
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CartIconButton(
                    iconColor: Colors.white,
                    iconSize: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ],
              onBack: () => Navigator.pop(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHeroCard(
                    cardColor: cardColor,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    userName: _userName,
                    userEmail: _userEmail,
                    initials: _initials(_userName),
                  ),
                  const SizedBox(height: 10),
                  _InfoSectionCard(
                    cardColor: cardColor,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    mutedColor: mutedColor,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    userName: _userName,
                    userEmail: _userEmail,
                    phoneDisplay:
                        _phoneNumber.isEmpty ? "Not provided" : _phoneNumber,
                  ),
                  const SizedBox(height: 10),
                  _DeliveryAddressCard(
                    cardColor: cardColor,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    mutedColor: mutedColor,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    loading: _loadingDeliveryAddress,
                    addressPreview: _deliveryAddressPreview,
                    onManage: _openDeliveryAddresses,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To change your name, email, or phone, contact customer support.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      height: 1.4,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SignOutCard(
                    isDark: isDark,
                    onPressed: _showLogoutDialog,
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.cardColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.userName,
    required this.userEmail,
    required this.initials,
  });

  final Color cardColor;
  final Color titleColor;
  final Color subtitleColor;
  final String userName;
  final String userEmail;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
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
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryLight,
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardColor,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
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

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
    required this.cardColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.userName,
    required this.userEmail,
    required this.phoneDisplay,
  });

  final Color cardColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color mutedColor;
  final Color fieldBg;
  final Color fieldBorder;
  final String userName;
  final String userEmail;
  final String phoneDisplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                        child: const Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal information',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Signed-in account',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: mutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Full name',
                    value: userName,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: userEmail,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.phone_android_rounded,
                    label: 'Phone',
                    value: phoneDisplay,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
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

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({
    required this.cardColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.loading,
    required this.addressPreview,
    required this.onManage,
  });

  final Color cardColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color mutedColor;
  final Color fieldBg;
  final Color fieldBorder;
  final bool loading;
  final String? addressPreview;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final previewText = loading
        ? 'Loading saved address…'
        : (addressPreview ?? 'No delivery address saved yet');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onManage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
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
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery addresses',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Saved delivery locations',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: mutedColor,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: fieldBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 17,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                previewText,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: addressPreview == null && !loading
                                      ? mutedColor
                                      : subtitleColor,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add or update your delivery address',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: mutedColor,
                          height: 1.35,
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.titleColor,
    required this.subtitleColor,
    required this.fieldBg,
    required this.fieldBorder,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color titleColor;
  final Color subtitleColor;
  final Color fieldBg;
  final Color fieldBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutCard extends StatelessWidget {
  const _SignOutCard({
    required this.isDark,
    required this.onPressed,
  });

  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2C1515) : const Color(0xFFFEF2F2);
    final border = isDark ? const Color(0xFF5C2A2A) : const Color(0xFFFECACA);
    final iconColor = isDark ? const Color(0xFFF87171) : Colors.red.shade600;
    final textColor = isDark ? const Color(0xFFFECACA) : Colors.red.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Sign out',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
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
