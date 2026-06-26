import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../models/user_profile.dart';
import '../main.dart';
import '../pages/map_picker_page.dart';
import '../pages/profilescreen.dart';
import '../providers/profile_settings_provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/app_error_utils.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

const Color _kPageBg = Color(0xFFF6F8FA);
const Color _kPageBgMint = Color(0xFFEFFCF4);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  String? _address;
  double? _lat;
  double? _lng;
  bool _loadingAddress = false;
  bool _isPrefilling = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProvider());
  }

  Future<void> _prefillFromProvider() async {
    final provider = context.read<ProfileSettingsProvider>();

    UserProfile? profile;
    try {
      await provider.loadProfile(forceRefresh: true);
      profile = provider.profile;
    } catch (_) {
      profile = provider.profile;
    }

    if (!_hasUsableProfile(profile)) {
      final local = await AuthService.getCurrentUser();
      if (local != null && local.isNotEmpty) {
        profile = UserProfile.fromLocalMap(local);
      }
    }

    if (!mounted) return;
    _applyProfileToForm(profile);

    if (_lat != null &&
        _lng != null &&
        (_address == null || _address!.isEmpty)) {
      await _resolveAddressFromCoordinates();
    }

    if (!mounted) return;
    setState(() => _isPrefilling = false);
  }

  bool _hasUsableProfile(UserProfile? profile) {
    if (profile == null) return false;
    return profile.name.trim().isNotEmpty ||
        profile.email.trim().isNotEmpty ||
        (profile.phone?.trim().isNotEmpty ?? false);
  }

  void _applyProfileToForm(UserProfile? profile) {
    _nameController.text = profile?.name ?? '';
    _emailController.text = profile?.email ?? '';
    _phoneController.text = profile?.phone ?? '';
    _address = profile?.address;
    _lat = profile?.lat;
    _lng = profile?.lng;
  }

  bool get _hasMapAddress =>
      _lat != null &&
      _lng != null &&
      _address != null &&
      _address!.trim().isNotEmpty;

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

  Future<void> _resolveAddressFromCoordinates() async {
    if (_lat == null || _lng == null) return;

    setState(() => _loadingAddress = true);
    try {
      final resolved = await _locationService.getAddressFromCoordinates(
        _lat!,
        _lng!,
      );
      if (!mounted) return;
      if (resolved != null && resolved.trim().isNotEmpty) {
        _address = resolved.trim();
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAddress = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _applyMapSelection(
    double lat,
    double lng,
    String? address,
  ) async {
    setState(() {
      _lat = lat;
      _lng = lng;
      _address = address?.trim().isNotEmpty == true ? address!.trim() : null;
      _loadingAddress = address == null || address.trim().isEmpty;
    });

    if (_address == null || _address!.isEmpty) {
      await _resolveAddressFromCoordinates();
    }
  }

  void _openMapPicker() {
    final initialLat = _lat ?? 5.6037;
    final initialLng = _lng ?? -0.1870;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          onLocationSelected: (lat, lng, address) {
            _applyMapSelection(lat, lng, address);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasMapAddress) {
      AppErrorUtils.showSnack(
        context,
        'Pick your address on the map to continue.',
        isError: true,
      );
      _openMapPicker();
      return;
    }

    final provider = context.read<ProfileSettingsProvider>();
    final ok = await provider.updateProfile(
      fname: _nameController.text,
      email: _emailController.text,
      number: _phoneController.text,
      addr1: _address,
      lat: _lat,
      lng: _lng,
    );
    if (!mounted) return;

    if (ok && provider.profile != null) {
      final profile = provider.profile!;
      context.read<UserProvider>().setUserData(
            userId: profile.id,
            userName: profile.name,
            userEmail: profile.email,
            userPhone: profile.phone,
            userAddress: profile.address,
          );
      AppErrorUtils.showSnack(context, 'Profile updated', isError: false);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    AppErrorUtils.showSnack(
      context,
      provider.error?.replaceFirst('Exception: ', '') ??
          'Could not update profile',
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final provider = context.watch<ProfileSettingsProvider>();
    final displayName = _nameController.text.trim().isEmpty
        ? 'Your profile'
        : _nameController.text.trim();

    return Scaffold(
      backgroundColor: theme.pageBg,
      body: _editProfileBackdrop(
        context: context,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              EclExpandableSliverAppBar(
                toolbarTitle: 'Edit profile',
                heroTitle: 'Edit profile',
                heroSubtitle: 'Keep your details up to date',
                onBack: () => Navigator.maybePop(context),
              ),
              if (_isPrefilling)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileSummaryCard(
                        cardColor: theme.surface,
                        titleColor: theme.ink,
                        subtitleColor: theme.muted,
                        name: displayName,
                        email: _emailController.text.trim().isEmpty
                            ? 'Add your email'
                            : _emailController.text.trim(),
                        initials: _initials(displayName),
                      ),
                      const SizedBox(height: 10),
                      _EditSectionCard(
                        cardColor: theme.surface,
                        titleColor: theme.ink,
                        mutedColor: theme.muted,
                        fieldBg: theme.fieldBg,
                        fieldBorder: theme.border,
                        title: 'Personal details',
                        subtitle: 'Name, email and phone',
                        icon: Icons.badge_outlined,
                        children: [
                          _EditField(
                            label: 'Full name',
                            icon: Icons.person_outline_rounded,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            ink: theme.ink,
                            muted: theme.muted,
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _EditField(
                            label: 'Email',
                            icon: Icons.mail_outline_rounded,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            ink: theme.ink,
                            muted: theme.muted,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'Enter your email';
                              if (!text.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _EditField(
                            label: 'Phone number',
                            icon: Icons.phone_android_rounded,
                            fieldBg: theme.fieldBg,
                            fieldBorder: theme.border,
                            ink: theme.ink,
                            muted: theme.muted,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _LocationSectionCard(
                        cardColor: theme.surface,
                        titleColor: theme.ink,
                        mutedColor: theme.muted,
                        address: _address,
                        loading: _loadingAddress,
                        hasCoordinates: _lat != null && _lng != null,
                        lat: _lat,
                        lng: _lng,
                        onTap: _openMapPicker,
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _SaveProfileBar(
        saving: provider.isSaving,
        onSave: _save,
      ),
    );
  }
}

Widget _editProfileBackdrop({
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
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

class _EditSectionCard extends StatelessWidget {
  const _EditSectionCard({
    required this.cardColor,
    required this.titleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.title,
    required this.subtitle,
    required this.icon,
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
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.icon,
    required this.fieldBg,
    required this.fieldBorder,
    required this.ink,
    required this.muted,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final String label;
  final IconData icon;
  final Color fieldBg;
  final Color fieldBorder;
  final Color ink;
  final Color muted;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              validator: validator,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
                floatingLabelStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSectionCard extends StatelessWidget {
  const _LocationSectionCard({
    required this.cardColor,
    required this.titleColor,
    required this.mutedColor,
    required this.address,
    required this.loading,
    required this.hasCoordinates,
    required this.lat,
    required this.lng,
    required this.onTap,
  });

  final Color cardColor;
  final Color titleColor;
  final Color mutedColor;
  final String? address;
  final bool loading;
  final bool hasCoordinates;
  final double? lat;
  final double? lng;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.trim().isNotEmpty;
    final theme = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
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
                Container(
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: theme.isDark
                          ? [
                              AppColors.primary.withValues(alpha: 0.22),
                              const Color(0xFF1A2E24),
                            ]
                          : [
                              const Color(0xFFE8F7EE),
                              const Color(0xFFD7EFE2),
                            ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 58,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasCoordinates ? 'Change on map' : 'Pick on map',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home address',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selected automatically from the map',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (loading)
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Getting address from map…',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        )
                      else if (hasAddress)
                        Text(
                          address!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: titleColor,
                            height: 1.4,
                          ),
                        )
                      else
                        Text(
                          'No address yet — tap above to choose your location.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: mutedColor,
                            height: 1.35,
                          ),
                        ),
                      if (hasCoordinates && lat != null && lng != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

class _SaveProfileBar extends StatelessWidget {
  const _SaveProfileBar({
    required this.saving,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottom + 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: saving ? null : onSave,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Save profile',
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
