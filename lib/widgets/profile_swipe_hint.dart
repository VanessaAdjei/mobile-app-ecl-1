import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tracks when to show the bottom swipe hint on profile-style scroll views.
class ProfileSwipeHintController {
  bool show = false;
  bool _dismissed = false;

  void reset() {
    show = false;
    _dismissed = false;
  }

  void update(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;

    final pixels = position.pixels;
    final maxExtent = position.maxScrollExtent;
    final canScroll = maxExtent > 32;
    final nearTop = pixels <= 8;
    final atBottom = maxExtent > 0 && pixels >= maxExtent - 12;

    if (pixels > 8 || atBottom) {
      _dismissed = true;
    }

    final shouldShow = !_dismissed && canScroll && nearTop;
    if (show != shouldShow) {
      show = shouldShow;
    }
  }
}

/// Bottom fade hint that content continues below the fold.
class ProfileSwipeHint extends StatelessWidget {
  const ProfileSwipeHint({
    super.key,
    required this.fadeColor,
    required this.mutedColor,
  });

  final Color fadeColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fadeColor.withValues(alpha: 0),
              fadeColor.withValues(alpha: 0.72),
              fadeColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: mutedColor,
            ),
            const SizedBox(width: 2),
            Text(
              'Swipe up for more',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void scheduleProfileSwipeHintCheck({
  required ScrollController controller,
  required ProfileSwipeHintController hint,
  required VoidCallback onChanged,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final previous = hint.show;
    hint.update(controller);
    if (previous != hint.show) {
      onChanged();
    }
  });
}
