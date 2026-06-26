import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../providers/profile_settings_provider.dart';
import '../utils/app_error_utils.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

const Color _kPageBg = Color(0xFFF6F8FA);
const Color _kPageBgMint = Color(0xFFEFFCF4);

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProfileSettingsProvider>();
    final error = await provider.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmPassword: _confirmController.text,
    );
    if (!mounted) return;

    if (error == null) {
      AppErrorUtils.showSnack(context, 'Password updated', isError: false);
      Navigator.pop(context, true);
      return;
    }

    AppErrorUtils.showSnack(context, error, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final provider = context.watch<ProfileSettingsProvider>();

    return Scaffold(
      backgroundColor: theme.pageBg,
      body: _changePasswordBackdrop(
        context: context,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              EclExpandableSliverAppBar(
                toolbarTitle: 'Change password',
                heroTitle: 'Change password',
                heroSubtitle: 'Keep your account secure',
                onBack: () => Navigator.maybePop(context),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SecuritySummaryCard(
                      cardColor: theme.surface,
                      titleColor: theme.ink,
                      subtitleColor: theme.muted,
                    ),
                    const SizedBox(height: 10),
                    _PasswordSectionCard(
                      cardColor: theme.surface,
                      titleColor: theme.ink,
                      mutedColor: theme.muted,
                      fieldBg: theme.fieldBg,
                      fieldBorder: theme.border,
                      ink: theme.ink,
                      currentController: _currentController,
                      newController: _newController,
                      confirmController: _confirmController,
                      showCurrent: _showCurrent,
                      showNew: _showNew,
                      showConfirm: _showConfirm,
                      onToggleCurrent: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      onToggleNew: () => setState(() => _showNew = !_showNew),
                      onToggleConfirm: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      onNewChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _PasswordTipsCard(
                      cardColor: theme.surface,
                      titleColor: theme.ink,
                      mutedColor: theme.muted,
                      fieldBg: theme.fieldBg,
                      fieldBorder: theme.border,
                      newPassword: _newController.text,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _UpdatePasswordBar(
        saving: provider.isChangingPassword,
        onSave: _submit,
      ),
    );
  }
}

Widget _changePasswordBackdrop({
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

class _SecuritySummaryCard extends StatelessWidget {
  const _SecuritySummaryCard({
    required this.cardColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color cardColor;
  final Color titleColor;
  final Color subtitleColor;

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
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade300,
                          Colors.orange.shade700,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.shade700.withValues(alpha: 0.24),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account security',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose a strong password you have not used elsewhere.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: subtitleColor,
                            height: 1.35,
                          ),
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

class _PasswordSectionCard extends StatelessWidget {
  const _PasswordSectionCard({
    required this.cardColor,
    required this.titleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.ink,
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.showCurrent,
    required this.showNew,
    required this.showConfirm,
    required this.onToggleCurrent,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onNewChanged,
  });

  final Color cardColor;
  final Color titleColor;
  final Color mutedColor;
  final Color fieldBg;
  final Color fieldBorder;
  final Color ink;
  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool showCurrent;
  final bool showNew;
  final bool showConfirm;
  final VoidCallback onToggleCurrent;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final ValueChanged<String> onNewChanged;

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
                          color: Colors.orange.shade700.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.vpn_key_outlined,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password details',
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              'Current and new password',
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
                  _PasswordField(
                    label: 'Current password',
                    icon: Icons.lock_clock_outlined,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    ink: ink,
                    muted: mutedColor,
                    controller: currentController,
                    visible: showCurrent,
                    onToggle: onToggleCurrent,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _PasswordField(
                    label: 'New password',
                    icon: Icons.lock_outline_rounded,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    ink: ink,
                    muted: mutedColor,
                    controller: newController,
                    visible: showNew,
                    onToggle: onToggleNew,
                    textInputAction: TextInputAction.next,
                    onChanged: onNewChanged,
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return 'Use at least 8 characters';
                      }
                      if (!RegExp(r'\d').hasMatch(value)) {
                        return 'Include at least one number';
                      }
                      if (value == currentController.text) {
                        return 'New password must differ from current';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _PasswordField(
                    label: 'Confirm new password',
                    icon: Icons.verified_user_outlined,
                    fieldBg: fieldBg,
                    fieldBorder: fieldBorder,
                    ink: ink,
                    muted: mutedColor,
                    controller: confirmController,
                    visible: showConfirm,
                    onToggle: onToggleConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your new password';
                      }
                      if (value != newController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.icon,
    required this.fieldBg,
    required this.fieldBorder,
    required this.ink,
    required this.muted,
    required this.controller,
    required this.visible,
    required this.onToggle,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  final String label;
  final IconData icon;
  final Color fieldBg;
  final Color fieldBorder;
  final Color ink;
  final Color muted;
  final TextEditingController controller;
  final bool visible;
  final VoidCallback onToggle;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
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
              obscureText: !visible,
              textInputAction: textInputAction,
              onChanged: onChanged,
              onFieldSubmitted: onFieldSubmitted,
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
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: muted,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

class _PasswordTipsCard extends StatelessWidget {
  const _PasswordTipsCard({
    required this.cardColor,
    required this.titleColor,
    required this.mutedColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.newPassword,
  });

  final Color cardColor;
  final Color titleColor;
  final Color mutedColor;
  final Color fieldBg;
  final Color fieldBorder;
  final String newPassword;

  @override
  Widget build(BuildContext context) {
    final hasMinLength = newPassword.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(newPassword);
    final hasDigit = RegExp(r'\d').hasMatch(newPassword);

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
                        child: const Icon(
                          Icons.shield_outlined,
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
                              'Password tips',
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              'A stronger password protects your account',
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
                    child: Column(
                      children: [
                        _TipRow(
                          met: hasMinLength,
                          label: 'At least 8 characters',
                          muted: mutedColor,
                          ink: titleColor,
                        ),
                        const SizedBox(height: 8),
                        _TipRow(
                          met: hasDigit,
                          label: 'Includes a number',
                          muted: mutedColor,
                          ink: titleColor,
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

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.met,
    required this.label,
    required this.muted,
    required this.ink,
  });

  final bool met;
  final String label;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: met ? AppColors.primary : muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: met ? ink : muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdatePasswordBar extends StatelessWidget {
  const _UpdatePasswordBar({
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
                'Update password',
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
