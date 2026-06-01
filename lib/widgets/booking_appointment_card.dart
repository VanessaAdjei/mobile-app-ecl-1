import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/pharmacists/pharmacists_booking_helpers.dart';
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
    final b = booking;
    final hasId = b['id'] != null;
    final isUpcoming = isBookingUpcoming(b);
    final isPastDue = isBookingPastDue(b);
    final isCompleted = isBookingCompleted(b);
    final isCancelled = isBookingCancelled(b);

    Color accentBar;
    Color badgeBg;
    Color badgeFg;
    if (isUpcoming) {
      accentBar = Colors.green.shade500;
      badgeBg = Colors.green.shade50;
      badgeFg = Colors.green.shade700;
    } else if (isPastDue) {
      accentBar = Colors.amber.shade700;
      badgeBg = Colors.amber.shade50;
      badgeFg = Colors.amber.shade900;
    } else if (isCompleted) {
      accentBar = const Color(0xFF1565C0);
      badgeBg = const Color(0xFFE3F2FD);
      badgeFg = const Color(0xFF0D47A1);
    } else if (isCancelled) {
      accentBar = Colors.grey.shade400;
      badgeBg = Colors.grey.shade100;
      badgeFg = Colors.grey.shade600;
    } else {
      accentBar = Colors.grey.shade400;
      badgeBg = Colors.grey.shade100;
      badgeFg = Colors.grey.shade700;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                                color: Colors.grey.shade800,
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
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow(
                              Icons.person_outline_rounded,
                              bookingDisplayName(b),
                            ),
                            const SizedBox(height: 8),
                            _detailRow(Icons.phone_outlined, b['phone'] ?? ''),
                            const SizedBox(height: 8),
                            _detailRow(Icons.email_outlined, b['email'] ?? ''),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.videocam_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${bookingDisplayConsultationType(b)} · ${bookingDisplayPlatform(b)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
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
                            color: Colors.grey.shade600,
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
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cancel booking',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade600,
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

  Widget _detailRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
