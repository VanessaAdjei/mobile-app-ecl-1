import 'package:eclapp/models/order_status_step.dart';
import 'package:eclapp/utils/order_timestamp_parser.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full vertical timeline — all steps visible with refined styling.
class PostCheckoutOrderProgressCard extends StatelessWidget {
  const PostCheckoutOrderProgressCard({
    super.key,
    required this.steps,
    required this.accent,
    this.animate = true,
  });

  final List<OrderStatusStep> steps;
  final Color accent;
  final bool animate;

  int get _currentIndex => steps.indexWhere((s) => s.isCurrent);

  int get _displayStep {
    final idx = _currentIndex;
    if (idx >= 0) return idx + 1;
    return steps.where((s) => s.isCompleted).length.clamp(1, steps.length);
  }

  OrderStatusStep get _currentStep {
    final idx = _currentIndex;
    if (idx >= 0) return steps[idx];
    final lastDone = steps.lastIndexWhere((s) => s.isCompleted);
    if (lastDone >= 0) return steps[lastDone];
    return steps.first;
  }

  double get _progressFraction {
    if (steps.isEmpty) return 0;
    final idx = _currentIndex;
    if (idx >= 0) return (idx + 1) / steps.length;
    final done = steps.where((s) => s.isCompleted).length;
    return done / steps.length;
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: PostCheckoutDesign.compactCard(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: accent),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrderProgressHeader(
                  accent: accent,
                  currentStep: _currentStep,
                  displayStep: _displayStep,
                  totalSteps: steps.length,
                  progress: _progressFraction,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  ...steps.asMap().entries.map((entry) {
                    final row = _ProgressStepRow(
                      step: entry.value,
                      isLast: entry.key == steps.length - 1,
                      accent: accent,
                    );
                    if (!animate) return row;
                    return row
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: (50 + entry.key * 60).ms,
                        )
                        .slideX(
                          begin: -0.04,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        );
                  }),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderProgressHeader extends StatelessWidget {
  const _OrderProgressHeader({
    required this.accent,
    required this.currentStep,
    required this.displayStep,
    required this.totalSteps,
    required this.progress,
  });

  final Color accent;
  final OrderStatusStep currentStep;
  final int displayStep;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PostCheckoutDesign.accentLight.withValues(alpha: 0.85),
            Colors.white,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: PostCheckoutDesign.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.route_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order progress',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PostCheckoutDesign.ink,
                        letterSpacing: -0.25,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentStep.title,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: PostCheckoutDesign.muted,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STEP',
                      style: GoogleFonts.poppins(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: PostCheckoutDesign.muted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$displayStep',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' / $totalSteps',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: PostCheckoutDesign.muted,
                              height: 1,
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
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: PostCheckoutDesign.border),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: ColoredBox(color: accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStepRow extends StatefulWidget {
  const _ProgressStepRow({
    required this.step,
    required this.isLast,
    required this.accent,
  });

  final OrderStatusStep step;
  final bool isLast;
  final Color accent;

  @override
  State<_ProgressStepRow> createState() => _ProgressStepRowState();
}

class _ProgressStepRowState extends State<_ProgressStepRow> {
  Timer? _elapsedTimer;

  OrderStatusStep get step => widget.step;
  Color get accent => widget.accent;
  bool get isLast => widget.isLast;

  @override
  void initState() {
    super.initState();
    _syncElapsedTimer();
  }

  @override
  void didUpdateWidget(covariant _ProgressStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElapsedTimer();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _syncElapsedTimer() {
    if (step.isCurrent) {
      _elapsedTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  static String _hintForStep(String id) {
    switch (id) {
      case 'orderPlaced':
        return 'Order received';
      case 'paid':
        return 'Payment cleared';
      case 'pendingConfirmation':
        return 'Store is reviewing';
      case 'orderConfirmed':
        return 'Being prepared';
      case 'orderDispatched':
        return 'Ready to leave the store';
      case 'outForDelivery':
        return 'On the way to you';
      case 'delivered':
        return 'At your address';
      case 'readyForPickup':
        return 'Collect in store';
      case 'pickedUp':
        return 'Handed to you';
      default:
        return '';
    }
  }

  static IconData _iconForStep(String id) {
    switch (id) {
      case 'orderPlaced':
        return Icons.receipt_long_rounded;
      case 'paid':
        return Icons.payments_rounded;
      case 'pendingConfirmation':
        return Icons.hourglass_top_rounded;
      case 'orderConfirmed':
        return Icons.verified_rounded;
      case 'orderDispatched':
        return Icons.inventory_2_outlined;
      case 'outForDelivery':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.home_rounded;
      case 'readyForPickup':
        return Icons.storefront_rounded;
      case 'pickedUp':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  static String? _formatCompletedTime(DateTime? at) {
    if (at == null) return null;
    return formatStepClockTime(at);
  }

  /// How long the order has been in this step (not "ago" from an arbitrary clock).
  static String? _formatActiveDuration(DateTime? at) {
    if (at == null) return null;
    return formatStepDuration(at);
  }

  @override
  Widget build(BuildContext context) {
    final done = step.isCompleted;
    final current = step.isCurrent;
    final pending = !done && !current;
    final hint = _hintForStep(step.id);
    final completedTime = done ? _formatCompletedTime(step.occurredAt) : null;
    final activeDuration =
        current ? _formatActiveDuration(step.occurredAt) : null;

    Widget node = _StepNode(
      done: done,
      current: current,
      accent: accent,
      icon: _iconForStep(step.id),
    );

    if (current) {
      node = node
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                node,
                if (!isLast)
                  Expanded(
                    child: _TimelineConnector(
                      filled: done,
                      accent: accent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(
                  current ? 10 : 0,
                  current ? 9 : 3,
                  current ? 10 : 0,
                  current ? 9 : 3,
                ),
                decoration: current
                    ? BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: GoogleFonts.poppins(
                              fontSize: current ? 13 : 12,
                              height: 1.2,
                              fontWeight:
                                  current ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: current ? -0.2 : 0,
                              color: pending
                                  ? PostCheckoutDesign.muted
                                      .withValues(alpha: 0.5)
                                  : done
                                      ? PostCheckoutDesign.muted
                                      : PostCheckoutDesign.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (completedTime != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              completedTime,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: PostCheckoutDesign.muted,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    if (current &&
                        (activeDuration != null || hint.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (activeDuration != null) ...[
                            Text(
                              activeDuration,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                                height: 1.2,
                              ),
                            ),
                            if (hint.isNotEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '·',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: PostCheckoutDesign.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (hint.isNotEmpty)
                            Expanded(
                              child: Text(
                                hint,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: PostCheckoutDesign.muted,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({
    required this.filled,
    required this.accent,
  });

  final bool filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        width: 2.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.5),
                    accent.withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: filled ? null : PostCheckoutDesign.border,
        ),
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.done,
    required this.current,
    required this.accent,
    required this.icon,
  });

  final bool done;
  final bool current;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;

    if (done) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Icon(Icons.check_rounded, size: 14, color: accent),
      );
    }

    if (current) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PostCheckoutDesign.pageBg,
        shape: BoxShape.circle,
        border: Border.all(color: PostCheckoutDesign.border),
      ),
      child: Icon(
        icon,
        size: 12,
        color: PostCheckoutDesign.muted.withValues(alpha: 0.45),
      ),
    );
  }
}
