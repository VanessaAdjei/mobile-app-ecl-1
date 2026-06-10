import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../pages/pharmacists/pharmacists_booking_helpers.dart';
import '../utils/app_theme_colors.dart';
import '../pages/pharmacists/pharmacists_bookings_sheet.dart';

/// Appointment card used on pharmacists sheet and My Appointments profile page.
class BookingAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<bool> Function(Map<String, dynamic> booking)? onCancel;

  const BookingAppointmentCard({
    super.key,
    required this.booking,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final b = booking;
    final hasId = b['id'] != null;
    final isUpcoming = isBookingUpcoming(b);
    final isPastDue = isBookingPastDue(b);
    final isCompleted = isBookingCompleted(b);
    final isCancelled = isBookingCancelled(b);

    final statusColors = _statusColors(
      theme: theme,
      isUpcoming: isUpcoming,
      isPastDue: isPastDue,
      isCompleted: isCompleted,
      isCancelled: isCancelled,
    );
    final accentBar = statusColors.$1;
    final badgeBg = statusColors.$2;
    final badgeFg = statusColors.$3;

    return Container(
      decoration: BoxDecoration(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.isDark ? 0.28 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, decoration: BoxDecoration(color: accentBar)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${bookingDisplayDate(b)} · ${bookingDisplayTime(b)}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.ink,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              getBookingStatus(b),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow(
                              theme,
                              Icons.person_outline_rounded,
                              bookingDisplayName(b),
                            ),
                            const SizedBox(height: 8),
                            _detailRow(
                              theme,
                              Icons.phone_outlined,
                              b['phone'] ?? '',
                            ),
                            const SizedBox(height: 8),
                            _detailRow(
                              theme,
                              Icons.email_outlined,
                              b['email'] ?? '',
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.videocam_outlined,
                                  size: 16,
                                  color: theme.muted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${bookingDisplayConsultationType(b)} · ${bookingDisplayPlatform(b)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: theme.muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (bookingDisplaySymptoms(b).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          bookingDisplaySymptoms(b),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: theme.muted,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (hasId && isUpcoming && onCancel != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) =>
                                      buildCancelBookingConfirmDialog(ctx),
                                );
                                if (confirm == true) {
                                  await onCancel!(b);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      size: 16,
                                      color: theme.isDark
                                          ? Colors.red.shade300
                                          : Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cancel booking',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.isDark
                                            ? Colors.red.shade300
                                            : Colors.red.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(AppThemeColors theme, IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: theme.ink.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  (Color, Color, Color) _statusColors({
    required AppThemeColors theme,
    required bool isUpcoming,
    required bool isPastDue,
    required bool isCompleted,
    required bool isCancelled,
  }) {
    if (isUpcoming) {
      return theme.isDark
          ? (
              AppColors.primaryLight,
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.primaryLight,
            )
          : (
              Colors.green.shade500,
              Colors.green.shade50,
              Colors.green.shade700,
            );
    }
    if (isPastDue) {
      return theme.isDark
          ? (
              Colors.amber.shade400,
              Colors.amber.withValues(alpha: 0.18),
              Colors.amber.shade200,
            )
          : (
              Colors.amber.shade700,
              Colors.amber.shade50,
              Colors.amber.shade900,
            );
    }
    if (isCompleted) {
      return theme.isDark
          ? (
              const Color(0xFF64B5F6),
              const Color(0xFF1565C0).withValues(alpha: 0.22),
              const Color(0xFF90CAF9),
            )
          : (
              const Color(0xFF1565C0),
              const Color(0xFFE3F2FD),
              const Color(0xFF0D47A1),
            );
    }
    if (isCancelled) {
      return theme.isDark
          ? (
              Colors.grey.shade500,
              Colors.white.withValues(alpha: 0.08),
              Colors.grey.shade400,
            )
          : (
              Colors.grey.shade400,
              Colors.grey.shade100,
              Colors.grey.shade600,
            );
    }
    return theme.isDark
        ? (
            Colors.grey.shade500,
            Colors.white.withValues(alpha: 0.08),
            Colors.grey.shade400,
          )
        : (
            Colors.grey.shade400,
            Colors.grey.shade100,
            Colors.grey.shade700,
          );
  }
}
