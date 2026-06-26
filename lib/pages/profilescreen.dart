// pages/profilescreen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../models/user_profile.dart';
import '../providers/profile_settings_provider.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import '../services/auth_service.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/logout_confirm_dialog.dart';
import '../widgets/profile_swipe_hint.dart';
import 'bottomnav.dart';
import 'loggedout.dart';

const Color _kPageBg = Color(0xFFF6F8FA);
const Color _kPageBgMint = Color(0xFFEFFCF4);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();
  String _userName = 'User';
  String _userEmail = 'No email available';
  String _phoneNumber = '';
  String? _homeAddress;
  bool _isLoading = true;
  final _swipeHint = ProfileSwipeHintController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfileData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final previous = _swipeHint.show;
    _swipeHint.update(_scrollController);
    if (previous != _swipeHint.show && mounted) {
      setState(() {});
    }
  }

  void _scheduleScrollHintCheck() {
    scheduleProfileSwipeHintCheck(
      controller: _scrollController,
      hint: _swipeHint,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProfileSettingsProvider>();
      await provider.loadProfile(forceRefresh: true);
      UserProfile? profile = provider.profile;

      if (!_hasUsableProfile(profile)) {
        final local = await AuthService.getCurrentUser();
        if (local != null && local.isNotEmpty) {
          profile = UserProfile.fromLocalMap(local);
        }
      }

      if (!mounted) return;

      if (profile == null) {
        final userData = await AuthService.getCurrentUser();
        if (!mounted) return;
        setState(() {
          _userName = userData?['name'] ?? 'User';
          _userEmail = userData?['email'] ?? 'No email available';
          _phoneNumber = userData?['phone'] ?? '';
          _homeAddress = userData?['addr_1']?.toString() ??
              userData?['address']?.toString();
          _isLoading = false;
        });
        _scheduleScrollHintCheck();
        return;
      }

      setState(() {
        _userName = profile!.name;
        _userEmail =
            profile.email.isNotEmpty ? profile.email : 'No email available';
        _phoneNumber = profile.phone ?? '';
        _homeAddress = profile.address;
        _isLoading = false;
      });
      _scheduleScrollHintCheck();
    } catch (e) {
      debugPrint('ProfileScreen: profile load failed: $e');
      if (!mounted) return;

      final userData = await AuthService.getCurrentUser();
      setState(() {
        _userName = userData?['name'] ?? 'User';
        _userEmail = userData?['email'] ?? 'No email available';
        _phoneNumber = userData?['phone'] ?? '';
        _homeAddress = userData?['addr_1']?.toString() ??
            userData?['address']?.toString();
        _isLoading = false;
      });
      _scheduleScrollHintCheck();
    }
  }

  bool _hasUsableProfile(UserProfile? profile) {
    if (profile == null) return false;
    return profile.name.trim().isNotEmpty ||
        profile.email.trim().isNotEmpty ||
        (profile.phone?.trim().isNotEmpty ?? false) ||
        (profile.address?.trim().isNotEmpty ?? false);
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (updated == true && mounted) {
      await _loadProfileData();
    }
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  void _showLogoutDialog() {
    LogoutConfirmDialog.show(
      context,
      onConfirm: () async {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoggedOutScreen()),
          (route) => false,
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
    final theme = context.appColors;
    final phoneDisplay =
        _phoneNumber.isEmpty ? 'Not provided' : _phoneNumber;

    return Scaffold(
      backgroundColor: theme.pageBg,
      body: _profileBackdrop(
        context: context,
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadProfileData,
              child: CustomScrollView(
                controller: _scrollController,
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
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileSummaryCard(
                        cardColor: theme.surface,
                        titleColor: theme.ink,
                        subtitleColor: theme.muted,
                        name: _userName,
                        email: _userEmail,
                        initials: _initials(_userName),
                      ),
                      const SizedBox(height: 8),
                      _ProfileSectionCard(
                        cardColor: theme.surface,
                        titleColor: theme.ink,
                        mutedColor: theme.muted,
                        fieldBg: theme.fieldBg,
                        fieldBorder: theme.border,
                        title: 'Your details',
                        subtitle: 'Contact info and home address',
                        icon: Icons.badge_outlined,
                        iconTint: AppColors.primary,
                        iconBg: AppColors.primary.withValues(alpha: 0.12),
                        children: [
                          _ProfileDetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Full name',
                            value: _userName,
                            ink: theme.ink,
                            muted: theme.muted,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                          ),
                          const SizedBox(height: 6),
                          _ProfileDetailRow(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: _userEmail,
                            ink: theme.ink,
                            muted: theme.muted,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                          ),
                          const SizedBox(height: 6),
                          _ProfileDetailRow(
                            icon: Icons.phone_android_rounded,
                            label: 'Phone',
                            value: phoneDisplay,
                            ink: theme.ink,
                            muted: theme.muted,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            isMutedValue: _phoneNumber.isEmpty,
                          ),
                          const SizedBox(height: 6),
                          _ProfileDetailRow(
                            icon: Icons.home_outlined,
                            label: 'Home address',
                            value: _hasAddress
                                ? _homeAddress!.trim()
                                : 'Not set yet',
                            ink: theme.ink,
                            muted: theme.muted,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            isMutedValue: !_hasAddress,
                            multiline: true,
                          ),
                          if (!_hasAddress) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Add your address on Edit profile.',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: theme.muted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ProfileSectionCard(
                        cardColor: theme.surface,
                        titleColor: theme.ink,
                        mutedColor: theme.muted,
                        fieldBg: theme.fieldBg,
                        fieldBorder: theme.border,
                        title: 'Account & security',
                        subtitle: 'Manage sign-in settings',
                        icon: Icons.shield_outlined,
                        iconTint: Colors.orange.shade700,
                        iconBg: Colors.orange.shade700.withValues(alpha: 0.12),
                        children: [
                          _ProfileActionRow(
                            icon: Icons.edit_outlined,
                            title: 'Edit profile',
                            subtitle: 'Update name, contact and address',
                            iconTint: AppColors.primary,
                            titleColor: theme.ink,
                            mutedColor: theme.muted,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            onTap: _openEditProfile,
                          ),
                          const SizedBox(height: 6),
                          _ProfileActionRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Change password',
                            subtitle: 'Update your sign-in password',
                            iconTint: Colors.orange.shade700,
                            titleColor: theme.ink,
                            mutedColor: theme.muted,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            onTap: _openChangePassword,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SignOutCard(
                        isDark: theme.isDark,
                        onPressed: _showLogoutDialog,
                      ),
                    ]),
                  ),
                ),
                ],
              ),
            ),
            if (_swipeHint.show && !_isLoading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ProfileSwipeHint(
                  fadeColor: theme.pageBg,
                  mutedColor: theme.muted,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  bool get _hasAddress =>
      _homeAddress != null && _homeAddress!.trim().isNotEmpty;
}

Widget _profileBackdrop({
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
                _kPageBgMint,
                _kPageBg,
                _kPageBg,
              ],
        stops: const [0.0, 0.28, 1.0],
      ),
    ),
    child: child,
  );
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.cardColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.name,
    required this.email,
    required this.initials,
  });

  final Color cardColor;
  final Color titleColor;
  final Color subtitleColor;
  final String name;
  final String email;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryLight,
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.24),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.cardColor,
    required this.titleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconTint,
    required this.iconBg,
    required this.children,
  });

  final Color cardColor;
  final Color titleColor;
  final Color mutedColor;
  final Color fieldBg;
  final Color fieldBorder;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconTint;
  final Color iconBg;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
                          color: iconBg,
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
                                color: titleColor,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: mutedColor,
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

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ink,
    required this.muted,
    required this.fieldBg,
    required this.fieldBorder,
    this.isMutedValue = false,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color ink;
  final Color muted;
  final Color fieldBg;
  final Color fieldBorder;
  final bool isMutedValue;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isMutedValue ? muted : ink,
                    height: multiline ? 1.4 : 1.2,
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

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconTint,
    required this.titleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconTint;
  final Color titleColor;
  final Color mutedColor;
  final Color fieldBg;
  final Color fieldBorder;
  final VoidCallback onTap;

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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconTint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 16, color: iconTint),
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
                        color: titleColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: mutedColor,
                size: 20,
              ),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: iconColor, size: 17),
                const SizedBox(width: 7),
                Text(
                  'Sign out',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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
