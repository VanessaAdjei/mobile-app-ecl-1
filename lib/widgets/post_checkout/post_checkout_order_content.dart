import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/services/order_tracking_service.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/providers/order_tracking_provider.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_action_buttons.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_entrance.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_items_card.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Animated post-checkout tracking layout (no map).
class PostCheckoutOrderContent extends StatefulWidget {
  const PostCheckoutOrderContent({
    super.key,
    required this.order,
    required this.provider,
    required this.accent,
    required this.onHome,
    required this.onSupport,
  });

  final OrderTrackingModel order;
  final OrderTrackingProvider provider;
  final Color accent;
  final VoidCallback onHome;
  final VoidCallback onSupport;

  @override
  State<PostCheckoutOrderContent> createState() =>
      _PostCheckoutOrderContentState();
}

class _PostCheckoutOrderContentState extends State<PostCheckoutOrderContent> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;

  OrderTrackingModel get order => widget.order;
  OrderTrackingProvider get provider => widget.provider;
  Color get accent => widget.accent;

  bool get _isPickup =>
      order.deliveryOption.toLowerCase().replaceAll('-', '').contains('pickup');

  String get _orderRef =>
      order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId;

  static Widget _enter(Widget child, int index, {double slideX = 0}) {
    return PostCheckoutEntrance(
      index: index,
      slideX: slideX,
      child: child,
    );
  }

  /// Prefer the timeline’s current step so the header card stays in sync with it.
  static OrderTrackingStage _displayStage(OrderTrackingModel order) {
    for (final step in order.timelineSteps) {
      if (!step.isCurrent) continue;
      for (final stage in OrderTrackingStage.values) {
        if (stage.name == step.id) return stage;
      }
    }
    return order.stage;
  }

  static bool _isPaymentSuccessStage(OrderTrackingStage stage) {
    return stage == OrderTrackingStage.paid ||
        stage == OrderTrackingStage.orderConfirmed ||
        stage == OrderTrackingStage.orderPlaced;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollHint();
    });
  }

  @override
  void didUpdateWidget(PostCheckoutOrderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollHint();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => _updateScrollHint();

  void _updateScrollHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final hasScrollableContent = position.maxScrollExtent > 1.0;
    final hasMoreBelow = position.pixels < position.maxScrollExtent - 12;
    final showHint = hasScrollableContent && hasMoreBelow;

    if (showHint != _showScrollHint) {
      setState(() => _showScrollHint = showHint);
    }
  }

  bool get _isDelivered => order.stage == OrderTrackingStage.delivered;

  @override
  Widget build(BuildContext context) {
    final placedAt = DateFormat('MMM d, y · h:mm a').format(order.createdAt);
    final address = order.deliveryAddress.trim();
    final displayStage = _displayStage(order);
    var index = 0;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: PostCheckoutDesign.pageBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _updateScrollHint();
              return false;
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(14, 10, 14, 24 + bottomInset),
              children: [
          _enter(
            _isDelivered
                ? _DeliveredStatusCard(
                    order: order,
                    accent: accent,
                    orderRef: _orderRef,
                  )
                : _isPaymentSuccessStage(displayStage)
                    ? _PaidStatusCard(
                        order: order,
                        displayStage: displayStage,
                        accent: accent,
                        orderRef: _orderRef,
                      )
                    : _StatusHeader(
                        order: order,
                        displayStage: displayStage,
                        accent: accent,
                        orderRef: _orderRef,
                      ),
            index++,
          ),
          if (_isDelivered) ...[
            const SizedBox(height: 10),
            _enter(
              _DeliveredMessageCard(accent: accent),
              index++,
            ),
          ],
          if (!_isDelivered) ...[
            const SizedBox(height: 10),
            _enter(
              _OrderPlacedDetailsCard(
                placedAt: placedAt,
                totalAmount: order.totalAmount,
                address: address,
                isPickup: _isPickup,
                accent: accent,
              ),
              index++,
            ),
          ],
          if (!_isPickup &&
              (order.stage == OrderTrackingStage.outForDelivery ||
                  order.stage == OrderTrackingStage.arrived)) ...[
            const SizedBox(height: 12),
            _enter(
              _DeliveryOtpNoticeCard(accent: accent),
              index++,
            ),
          ],
          if (provider.errorMessage != null &&
              provider.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _enter(
              _AlertBanner(
                message: provider.errorMessage!,
                onTap: provider.refreshTracking,
              ),
              index++,
            ),
          ],
          if (!_isDelivered) ...[
            const SizedBox(height: 12),
            _enter(
              PostCheckoutOrderProgressCard(
                steps: order.timelineSteps,
                accent: accent,
                animate: true,
              ),
              index++,
            ),
          ],
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _enter(
              PostCheckoutOrderItemsCard(
                items: order.items,
                accent: accent,
                animate: true,
              ),
              index++,
            ),
          ],
          const SizedBox(height: 16),
          _enter(
            PostCheckoutActionButtons(
              accent: accent,
              onHome: widget.onHome,
              onSupport: widget.onSupport,
              animate: false,
            ),
            index++,
          ),
              ],
            ),
          ),
          if (_showScrollHint)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _PostCheckoutScrollHint(accent: accent),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom fade + label when post-checkout content extends below the fold.
class _PostCheckoutScrollHint extends StatelessWidget {
  const _PostCheckoutScrollHint({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg = PostCheckoutDesign.pageBg;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg.withValues(alpha: 0), bg],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: bg,
          padding: EdgeInsets.only(bottom: 4 + bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 4),
              Text(
                'Scroll for more',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PostCheckoutDesign.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated payment-waiting screen.
class PostCheckoutPendingContent extends StatefulWidget {
  const PostCheckoutPendingContent({
    super.key,
    required this.order,
    required this.provider,
    required this.accent,
    required this.onHome,
  });

  final OrderTrackingModel order;
  final OrderTrackingProvider provider;
  final Color accent;
  final VoidCallback onHome;

  @override
  State<PostCheckoutPendingContent> createState() =>
      _PostCheckoutPendingContentState();
}

class _PostCheckoutPendingContentState extends State<PostCheckoutPendingContent> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;

  OrderTrackingModel get order => widget.order;
  OrderTrackingProvider get provider => widget.provider;
  Color get accent => widget.accent;

  bool get _isPickup =>
      order.deliveryOption.toLowerCase().replaceAll('-', '').contains('pickup');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollHint();
    });
  }

  @override
  void didUpdateWidget(PostCheckoutPendingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollHint();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => _updateScrollHint();

  void _updateScrollHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final hasScrollableContent = position.maxScrollExtent > 1.0;
    final hasMoreBelow = position.pixels < position.maxScrollExtent - 12;
    final showHint = hasScrollableContent && hasMoreBelow;

    if (showHint != _showScrollHint) {
      setState(() => _showScrollHint = showHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderRef =
        order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId;
    final checking = provider.isLoading || provider.isRefreshing;
    final placedAt = DateFormat('MMM d, y · h:mm a').format(order.createdAt);
    final address = order.deliveryAddress.trim();

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: PostCheckoutDesign.pageBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _updateScrollHint();
              return false;
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(14, 10, 14, 24 + bottomInset),
              children: [
          PostCheckoutEntrance(
            index: 0,
            child: _PendingStatusCard(
              accent: accent,
              checking: checking,
              orderRef: orderRef,
            ),
          ),
          const SizedBox(height: 10),
          PostCheckoutEntrance(
            index: 1,
            child: _OrderPlacedDetailsCard(
              placedAt: placedAt,
              totalAmount: order.totalAmount,
              address: address,
              isPickup: _isPickup,
              accent: accent,
            ),
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            PostCheckoutEntrance(
              index: 2,
              child: PostCheckoutOrderItemsCard(
                items: order.items,
                accent: accent,
                animate: true,
              ),
            ),
          ],
          const SizedBox(height: 14),
          PostCheckoutEntrance(
            index: 3,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF9F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBEAD3)),
              ),
              child: Text(
                'Stay here or go home — we will keep checking and update this screen.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PostCheckoutEntrance(
            index: 4,
            child: PostCheckoutActionButtons(
              accent: accent,
              onHome: widget.onHome,
              showSupport: false,
              animate: false,
            ),
          ),
              ],
            ),
          ),
          if (_showScrollHint)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _PostCheckoutScrollHint(accent: accent),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact payment-success hero (Paid / Order placed / Order confirmed).
class _PaidStatusCard extends StatelessWidget {
  const _PaidStatusCard({
    required this.order,
    required this.displayStage,
    required this.accent,
    required this.orderRef,
  });

  final OrderTrackingModel order;
  final OrderTrackingStage displayStage;
  final Color accent;
  final String orderRef;

  String get _badgeLabel {
    switch (displayStage) {
      case OrderTrackingStage.orderConfirmed:
        return 'CONFIRMED';
      case OrderTrackingStage.orderPlaced:
        return 'PLACED';
      case OrderTrackingStage.paid:
      default:
        return 'PAID';
    }
  }

  String get _headline {
    switch (displayStage) {
      case OrderTrackingStage.orderConfirmed:
        return 'Order confirmed';
      case OrderTrackingStage.orderPlaced:
        return 'Order placed';
      case OrderTrackingStage.paid:
      default:
        return 'Payment received';
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = OrderTrackingService().stageMessage(displayStage).trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PostCheckoutDesign.accentLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostCheckoutDesign.logoMark(
                    size: 36,
                    borderColor: accent.withValues(alpha: 0.2),
                    overlay: PostCheckoutDesign.successCheckOverlay(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _headline,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PostCheckoutDesign.ink,
                                  letterSpacing: -0.2,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                _badgeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            message,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: PostCheckoutDesign.muted,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (orderRef.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _OrderIdRow(reference: orderRef, accent: accent),
                        ],
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

/// Delivered-state hero — matches compact confirmation card styling.
class _DeliveredStatusCard extends StatelessWidget {
  const _DeliveredStatusCard({
    required this.order,
    required this.accent,
    required this.orderRef,
  });

  final OrderTrackingModel order;
  final Color accent;
  final String orderRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PostCheckoutDesign.accentLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostCheckoutDesign.logoMark(
                    size: 44,
                    borderColor: accent.withValues(alpha: 0.2),
                    overlay: PostCheckoutDesign.successCheckOverlay(size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Your order has arrived',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: PostCheckoutDesign.ink,
                                  letterSpacing: -0.25,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'DELIVERED',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (orderRef.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _OrderIdRow(reference: orderRef, accent: accent),
                        ],
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

/// Appreciation copy from the original delivered screen (below status hero).
class _DeliveredMessageCard extends StatelessWidget {
  const _DeliveredMessageCard({required this.accent});

  final Color accent;

  static const _lead =
      'We appreciate you choosing us for your health and wellness essentials.';
  static const _followUp =
      'Thank you. Remember, we are always ready to assist the best way possible.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: PostCheckoutDesign.compactCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _lead,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PostCheckoutDesign.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _followUp,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: PostCheckoutDesign.muted,
              height: 1.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 1.5,
                  color: PostCheckoutDesign.border,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 28,
                  height: 1.5,
                  color: PostCheckoutDesign.border,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCheckoutMetricColumn extends StatelessWidget {
  const _PostCheckoutMetricColumn({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: PostCheckoutDesign.muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? PostCheckoutDesign.ink,
            height: 1.2,
            letterSpacing: -0.15,
          ),
        ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.order,
    required this.displayStage,
    required this.accent,
    required this.orderRef,
  });

  final OrderTrackingModel order;
  final OrderTrackingStage displayStage;
  final Color accent;
  final String orderRef;

  IconData _iconForStage() {
    switch (displayStage) {
      case OrderTrackingStage.failed:
        return Icons.error_outline_rounded;
      case OrderTrackingStage.orderDispatched:
        return Icons.inventory_2_outlined;
      case OrderTrackingStage.outForDelivery:
        return Icons.delivery_dining_rounded;
      case OrderTrackingStage.arrived:
        return Icons.place_rounded;
      case OrderTrackingStage.delivered:
        return Icons.check_circle_rounded;
      default:
        return Icons.local_pharmacy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = OrderTrackingService();
    final stageLabel = tracking.stageLabel(displayStage);
    final stageMessage = tracking.stageMessage(displayStage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: PostCheckoutDesign.compactCard(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForStage(), size: 20, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stageLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PostCheckoutDesign.ink,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                if (orderRef.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _OrderIdRow(reference: orderRef, accent: accent),
                ],
                if (stageMessage.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    stageMessage,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: PostCheckoutDesign.muted,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderIdRow extends StatelessWidget {
  const _OrderIdRow({
    required this.reference,
    required this.accent,
  });

  final String reference;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style:
            GoogleFonts.poppins(fontSize: 11, color: PostCheckoutDesign.muted),
        children: [
          const TextSpan(text: 'Order '),
          TextSpan(
            text: reference,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PendingStatusCard extends StatelessWidget {
  const _PendingStatusCard({
    required this.accent,
    required this.checking,
    required this.orderRef,
  });

  final Color accent;
  final bool checking;
  final String orderRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PostCheckoutDesign.compactCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PostCheckoutDesign.logoMark(
                  size: 36,
                  backgroundColor: accent.withValues(alpha: 0.06),
                  borderColor: PostCheckoutDesign.border,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verifying payment',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PostCheckoutDesign.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        checking
                            ? 'Checking with your payment provider…'
                            : 'Waiting for verification',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: PostCheckoutDesign.muted,
                          height: 1.35,
                        ),
                      ),
                      if (orderRef.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _OrderIdRow(reference: orderRef, accent: accent),
                      ],
                      if (checking) ...[
                        const SizedBox(height: 8),
                        _AnimatedDots(color: accent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: PostCheckoutDesign.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 11),
            child: _PendingProgressStrip(accent: accent, isActive: checking),
          ),
        ],
      ),
    );
  }
}

/// Order placed time, total, and delivery/pickup address in one compact card.
class _OrderPlacedDetailsCard extends StatelessWidget {
  const _OrderPlacedDetailsCard({
    required this.placedAt,
    required this.totalAmount,
    required this.address,
    required this.isPickup,
    required this.accent,
  });

  final String placedAt;
  final double totalAmount;
  final String address;
  final bool isPickup;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.isNotEmpty;
    final addressLabel = isPickup ? 'PICKUP' : 'DELIVERY';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: PostCheckoutDesign.compactCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PostCheckoutMetricColumn(
                    label: 'PLACED',
                    value: placedAt,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: PostCheckoutDesign.border,
                ),
                Expanded(
                  child: _PostCheckoutMetricColumn(
                    label: 'TOTAL',
                    value: 'GHS ${totalAmount.toStringAsFixed(2)}',
                    valueColor: accent,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          if (hasAddress) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Divider(height: 1, color: PostCheckoutDesign.border),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$addressLabel · ',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: PostCheckoutDesign.muted,
                    ),
                  ),
                  TextSpan(
                    text: address,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: PostCheckoutDesign.ink,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown while the order is out for delivery — OTP is sent when the rider arrives.
class _DeliveryOtpNoticeCard extends StatelessWidget {
  const _DeliveryOtpNoticeCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: PostCheckoutDesign.accentLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sms_outlined,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'An OTP will be sent when the rider arrives with your package.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PostCheckoutDesign.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.message, required this.onTap});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots({required this.color});

  final Color color;

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.2) % 1.0;
            final opacity =
                0.35 + 0.65 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Container(
              margin: const EdgeInsets.only(right: 5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _PendingProgressStrip extends StatelessWidget {
  const _PendingProgressStrip({
    required this.accent,
    required this.isActive,
  });

  final Color accent;
  final bool isActive;

  static const double _connectorWidth = 40;
  static const double _stepSize = 24;

  @override
  Widget build(BuildContext context) {
    final labels = ['Payment', 'Verify', 'Confirmed'];
    final lineColor = Colors.grey.shade300;
    final activeLine = accent.withValues(alpha: 0.5);

    Widget step(int index) {
      final activeStep = index == 0 || (isActive && index <= 1);
      return SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: _stepSize,
              height: _stepSize,
              decoration: BoxDecoration(
                color: activeStep
                    ? accent.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      activeStep ? accent.withValues(alpha: 0.35) : lineColor,
                ),
              ),
              child: Center(
                child: index == 0
                    ? Icon(Icons.check_rounded, size: 12, color: accent)
                    : isActive && index == 1
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: accent,
                            ),
                          )
                        : Icon(
                            Icons.more_horiz,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
              ),
            ).animate(target: isActive && index == 1 ? 1 : 0).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 600.ms,
                ),
            const SizedBox(height: 4),
            Text(
              labels[index],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: PostCheckoutDesign.muted,
              ),
            ),
          ],
        ),
      );
    }

    Widget connector(int afterIndex) {
      return Padding(
        padding: const EdgeInsets.only(top: 13),
        child: SizedBox(
          width: _connectorWidth,
          child: Container(
            height: 2,
            color: afterIndex == 1 && isActive ? activeLine : lineColor,
          ),
        ),
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step(0),
          connector(1),
          step(1),
          connector(2),
          step(2),
        ],
      ),
    );
  }
}
