import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

/// Floating contact sheet — Quick Actions → Contact. Fits without scrolling.
class ContactUsSheet {
  ContactUsSheet._();

  static const _phones = ['0302908674', '0302908675'];
  static const whatsapp = '0508411184';
  static const email = 'commerce@ecl.com.gh';

  static Future<void> show(
    BuildContext context, {
    required void Function(String phone) onCall,
    required VoidCallback onWhatsApp,
    required VoidCallback onEmail,
    required VoidCallback onFindStore,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      builder: (sheetContext) => _ContactUsSheetBody(
        onCall: onCall,
        onWhatsApp: onWhatsApp,
        onEmail: onEmail,
        onFindStore: onFindStore,
      ),
    );
  }
}

class _ContactUsSheetBody extends StatelessWidget {
  const _ContactUsSheetBody({
    required this.onCall,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onFindStore,
  });

  final void Function(String phone) onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onFindStore;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final accent =
        theme.isDark ? AppColors.primaryLight : AppColors.primaryDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: theme.sheetBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.border),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: theme.isDark ? 0.12 : 0.1),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.45 : 0.12,
                ),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.handleBar,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, AppColors.primaryDark],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.headset_mic_rounded,
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
                                  'Contact us',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: theme.ink,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'We usually reply within 1 business day',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: theme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _WhatsAppButton(
                        onTap: () => _closeThen(context, onWhatsApp),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              color: const Color(0xFF2563EB),
                              onTap: () => _closeThen(context, onEmail),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.storefront_outlined,
                              label: 'Stores',
                              color: const Color(0xFFEA580C),
                              onTap: () => _closeThen(context, onFindStore),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0;
                              i < ContactUsSheet._phones.length;
                              i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _PhoneChip(
                                number: ContactUsSheet._phones[i],
                                accent: accent,
                                onTap: () => _closeThen(
                                  context,
                                  () => onCall(ContactUsSheet._phones[i]),
                                ),
                              ),
                            ),
                          ],
                        ],
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

void _closeThen(BuildContext context, VoidCallback action) {
  Navigator.pop(context);
  action();
}

class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton({required this.onTap});

  final VoidCallback onTap;

  String _formatNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final formatted = _formatNumber(ContactUsSheet.whatsapp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.whatsapp.withValues(alpha: theme.isDark ? 0.32 : 0.2),
            ),
            boxShadow: [
              if (!theme.isDark)
                BoxShadow(
                  color: AppColors.whatsapp.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: AppColors.whatsapp),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.whatsapp,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'WhatsApp',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.ink,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              formatted,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.muted,
                                letterSpacing: 0.2,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 15,
                        color: AppColors.whatsapp.withValues(
                          alpha: theme.isDark ? 0.9 : 0.75,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Material(
      color: theme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: theme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneChip extends StatelessWidget {
  const _PhoneChip({
    required this.number,
    required this.accent,
    required this.onTap,
  });

  final String number;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Material(
      color: theme.isDark
          ? Colors.white.withValues(alpha: 0.04)
          : const Color(0xFFFAFCFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.phone_rounded, color: accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    number,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.ink,
                      letterSpacing: 0.2,
                    ),
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
