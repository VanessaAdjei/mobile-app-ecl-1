import 'dart:async';

import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SpotlightTooltipAlign { above, below, auto }

class SpotlightStep {
  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.align = SpotlightTooltipAlign.auto,
    this.padding = 8,
    this.beforeShow,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final SpotlightTooltipAlign align;
  final double padding;
  final Future<void> Function()? beforeShow;
}

/// Full-screen coach marks that dim the UI and highlight a target widget.
class SpotlightTour {
  SpotlightTour._();

  static Rect? targetRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  static Future<void> show({
    required BuildContext context,
    required List<SpotlightStep> steps,
    VoidCallback? onFinished,
  }) async {
    if (steps.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final completer = Completer<void>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _SpotlightTourOverlay(
        steps: steps,
        onDone: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
          onFinished?.call();
        },
      ),
    );

    overlay.insert(entry);
    await completer.future;
  }
}

class _SpotlightTourOverlay extends StatefulWidget {
  const _SpotlightTourOverlay({
    required this.steps,
    required this.onDone,
  });

  final List<SpotlightStep> steps;
  final VoidCallback onDone;

  @override
  State<_SpotlightTourOverlay> createState() => _SpotlightTourOverlayState();
}

class _SpotlightTourOverlayState extends State<_SpotlightTourOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Rect? _hole;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep(0));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _showStep(int index) async {
    if (!mounted) return;
    if (index >= widget.steps.length) {
      widget.onDone();
      return;
    }

    final step = widget.steps[index];
    if (step.beforeShow != null) {
      await step.beforeShow!();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    Rect? rect;
    for (var attempt = 0; attempt < 12; attempt++) {
      rect = SpotlightTour.targetRect(step.targetKey);
      if (rect != null && rect.width > 8 && rect.height > 8) break;
      await Future<void>.delayed(const Duration(milliseconds: 32));
    }

    if (!mounted) return;
    setState(() {
      _index = index;
      _hole = rect?.inflate(step.padding);
    });
  }

  void _next() {
    final next = _index + 1;
    if (next >= widget.steps.length) {
      widget.onDone();
    } else {
      unawaited(_showStep(next));
    }
  }

  void _skip() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final size = MediaQuery.sizeOf(context);
    final hole = _hole;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _SpotlightPainter(
                  hole: hole,
                  pulse: _pulse.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (hole != null)
            Positioned(
              left: hole.left,
              top: hole.top,
              width: hole.width,
              height: hole.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: 0.5 + _pulse.value * 0.35,
                      ),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          if (hole != null)
            _TooltipCard(
              hole: hole,
              screenSize: size,
              title: step.title,
              body: step.body,
              align: step.align,
              index: _index,
              total: widget.steps.length,
              onNext: _next,
              onSkip: _skip,
              isLast: _index == widget.steps.length - 1,
            )
          else
            Center(
              child: _FallbackTooltip(
                title: step.title,
                body: step.body,
                index: _index,
                total: widget.steps.length,
                onNext: _next,
                onSkip: _skip,
                isLast: _index == widget.steps.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.pulse});

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final full = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (hole != null) {
      final r = hole!.inflate(4 + pulse * 4);
      final cut = Path()
        ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)));
      final overlay = Path.combine(PathOperation.difference, full, cut);
      canvas.drawPath(overlay, paint);
    } else {
      canvas.drawPath(full, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse;
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.hole,
    required this.screenSize,
    required this.title,
    required this.body,
    required this.align,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  final Rect hole;
  final Size screenSize;
  final String title;
  final String body;
  final SpotlightTooltipAlign align;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const cardMaxWidth = 320.0;
    const cardHeightEstimate = 160.0;
    const gap = 14.0;

    var preferBelow = switch (align) {
      SpotlightTooltipAlign.below => true,
      SpotlightTooltipAlign.above => false,
      SpotlightTooltipAlign.auto =>
        hole.bottom + cardHeightEstimate + gap < screenSize.height * 0.85,
    };

    double topForBelow() =>
        (hole.bottom + gap).clamp(16.0, screenSize.height - cardHeightEstimate - 16);
    double topForAbove() => (hole.top - cardHeightEstimate - gap)
        .clamp(16.0, screenSize.height - cardHeightEstimate - 16);

    double top = preferBelow ? topForBelow() : topForAbove();
    final cardRect = Rect.fromLTWH(0, top, cardMaxWidth, cardHeightEstimate);
    if (cardRect.overlaps(hole)) {
      preferBelow = !preferBelow;
      top = preferBelow ? topForBelow() : topForAbove();
    }

    final centerX = hole.center.dx;
    final left = (centerX - cardMaxWidth / 2)
        .clamp(16.0, screenSize.width - cardMaxWidth - 16);

    return Positioned(
      left: left,
      top: top,
      width: cardMaxWidth,
      child: _TooltipContent(
        title: title,
        body: body,
        index: index,
        total: total,
        onNext: onNext,
        onSkip: onSkip,
        isLast: isLast,
        arrowUp: !preferBelow,
        arrowX: (centerX - left).clamp(24.0, cardMaxWidth - 24),
      ),
    );
  }
}

class _TooltipContent extends StatelessWidget {
  const _TooltipContent({
    required this.title,
    required this.body,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
    this.arrowUp = false,
    this.arrowX = 24,
  });

  final String title;
  final String body;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;
  final bool arrowUp;
  final double arrowX;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (arrowUp)
          CustomPaint(
            size: const Size(double.infinity, 10),
            painter: _ArrowPainter(pointingUp: true, offsetX: arrowX),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '${index + 1} of $total',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onSkip,
                    child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Skip tour',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isLast ? 'Done' : 'Next',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!arrowUp)
          CustomPaint(
            size: const Size(double.infinity, 10),
            painter: _ArrowPainter(pointingUp: false, offsetX: arrowX),
          ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.pointingUp, required this.offsetX});

  final bool pointingUp;
  final double offsetX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    if (pointingUp) {
      path.moveTo(offsetX, size.height);
      path.lineTo(offsetX - 10, 0);
      path.lineTo(offsetX + 10, 0);
    } else {
      path.moveTo(offsetX, 0);
      path.lineTo(offsetX - 10, size.height);
      path.lineTo(offsetX + 10, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.pointingUp != pointingUp || old.offsetX != offsetX;
}

class _FallbackTooltip extends StatelessWidget {
  const _FallbackTooltip({
    required this.title,
    required this.body,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  final String title;
  final String body;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _TooltipContent(
        title: title,
        body: body,
        index: index,
        total: total,
        onNext: onNext,
        onSkip: onSkip,
        isLast: isLast,
      ),
    );
  }
}
