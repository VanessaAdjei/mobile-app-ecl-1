import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_action_buttons.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_entrance.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_items_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Guest post-checkout: calm receipt + off-app updates (no live timeline).
class PostCheckoutGuestOrderContent extends StatefulWidget {
  const PostCheckoutGuestOrderContent({
    super.key,
    required this.order,
    required this.accent,
    required this.onHome,
    required this.onSupport,
    required this.isPickup,
  });

  final OrderTrackingModel order;
  final Color accent;
  final VoidCallback onHome;
  final VoidCallback onSupport;
  final bool isPickup;

  @override
  State<PostCheckoutGuestOrderContent> createState() =>
      _PostCheckoutGuestOrderContentState();
}

class _PostCheckoutGuestOrderContentState
    extends State<PostCheckoutGuestOrderContent> {
  static const double _sectionGap = 20;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;

  OrderTrackingModel get order => widget.order;
  Color get accent => widget.accent;

  String get _orderRef =>
      order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId;

  String get _phone => order.contactNumber.trim();

  String get _email {
    final params = order.paymentParams;
    for (final key in ['email', 'user_email', 'guest_email', 'customer_email']) {
      final value = params[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static Widget _enter(Widget child, int index) {
    return PostCheckoutEntrance(index: index, child: child);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollHint();
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _updateScrollHint();
      });
    });
  }

  @override
  void didUpdateWidget(PostCheckoutGuestOrderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollHint();
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _updateScrollHint();
      });
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
    final placedAt = DateFormat('MMM d, y · h:mm a').format(order.createdAt);
    final address = order.deliveryAddress.trim();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    var index = 0;

    return ColoredBox(
      color: PostCheckoutDesign.pageBg(context),
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
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                28 + bottomInset + (_showScrollHint ? 52 : 0),
              ),
              children: [
                _enter(
                  _GuestPlacedHero(
                    accent: accent,
                    orderRef: _orderRef,
                  ),
                  index++,
                ),
                const SizedBox(height: _sectionGap),
                _enter(
                  _GuestUpdatesPanel(
                    accent: accent,
                    phone: _phone,
                    email: _email,
                    isPickup: widget.isPickup,
                  ),
                  index++,
                ),
                const SizedBox(height: _sectionGap),
                _enter(
                  _GuestReceiptSection(
                    accent: accent,
                    placedAt: placedAt,
                    totalAmount: order.totalAmount,
                    address: address,
                    isPickup: widget.isPickup,
                    paymentMethod: order.paymentMethod,
                    estimatedDeliveryTime: order.estimatedDeliveryTime,
                    items: order.items,
                  ),
                  index++,
                ),
                const SizedBox(height: 24),
                _enter(
                  PostCheckoutActionButtons(
                    accent: accent,
                    onHome: widget.onHome,
                    onSupport: widget.onSupport,
                    animate: false,
                    breathingPrimary: false,
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
                child: _GuestScrollHint(accent: accent),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom fade + label when guest confirmation extends below the fold.
class _GuestScrollHint extends StatelessWidget {
  const _GuestScrollHint({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg = PostCheckoutDesign.pageBg(context);
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
                Icons.swipe_vertical_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 4),
              Text(
                'Swipe for more',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PostCheckoutDesign.ink(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestPlacedHero extends StatelessWidget {
  const _GuestPlacedHero({
    required this.accent,
    required this.orderRef,
  });

  final Color accent;
  final String orderRef;

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final accentDark = Color.lerp(accent, Colors.black, 0.15) ?? accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            PostCheckoutDesign.accentLight(context).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accentDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            'Order placed',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: PostCheckoutDesign.ink(context),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          if (orderRef.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: t.isDark
                    ? t.surface.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Ref · $orderRef',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentDark,
                ),
              ),
            )
          else
            Text(
              'Thank you for shopping with us',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PostCheckoutDesign.muted(context),
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}

class _GuestUpdatesPanel extends StatelessWidget {
  const _GuestUpdatesPanel({
    required this.accent,
    required this.phone,
    required this.email,
    required this.isPickup,
  });

  final Color accent;
  final String phone;
  final String email;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.isNotEmpty;
    final hasEmail = email.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PostCheckoutDesign.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: PostCheckoutDesign.cardShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              color: accent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 20,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'How we\'ll reach you',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PostCheckoutDesign.ink(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order updates are sent by text and email — not in this app.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: PostCheckoutDesign.muted(context),
                      height: 1.5,
                    ),
                  ),
                  if (hasPhone || hasEmail) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hasPhone)
                          _ContactChip(
                            icon: Icons.sms_outlined,
                            label: phone,
                            tint: Colors.green.shade50,
                            iconColor: Colors.green.shade700,
                            borderColor: Colors.green.shade200,
                          ),
                        if (hasEmail)
                          _ContactChip(
                            icon: Icons.mail_outline_rounded,
                            label: email,
                            tint: Colors.blue.shade50,
                            iconColor: Colors.blue.shade700,
                            borderColor: Colors.blue.shade100,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _bullet(
                    context,
                    accent,
                    isPickup
                        ? 'We\'ll notify you when your order is ready for pickup.'
                        : 'Dispatch and delivery updates arrive by text and email.',
                  ),
                  const SizedBox(height: 8),
                  _bullet(
                    context,
                    accent,
                    isPickup
                        ? 'Bring your reference number when you collect.'
                        : 'Your rider OTP will be sent by text when they arrive.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, Color accent, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PostCheckoutDesign.ink(context),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PostCheckoutDesign.ink(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestReceiptSection extends StatelessWidget {
  const _GuestReceiptSection({
    required this.accent,
    required this.placedAt,
    required this.totalAmount,
    required this.address,
    required this.isPickup,
    required this.paymentMethod,
    required this.estimatedDeliveryTime,
    required this.items,
  });

  final Color accent;
  final String placedAt;
  final double totalAmount;
  final String address;
  final bool isPickup;
  final String paymentMethod;
  final String estimatedDeliveryTime;
  final List<OrderTrackingItem> items;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2)
        .format(totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: PostCheckoutDesign.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PostCheckoutDesign.border(context)),
            boxShadow: PostCheckoutDesign.cardShadow(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: accent.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 20, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Your order',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PostCheckoutDesign.ink(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              _detailRow(context, 'Placed', placedAt),
              const SizedBox(height: 10),
              _detailRow(
                context,
                'Total',
                amount,
                valueColor: accent,
                bold: true,
                highlight: true,
              ),
              if (paymentMethod.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailRow(context, 'Payment', paymentMethod),
              ],
              if (address.isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailRow(
                  context,
                  isPickup ? 'Pickup' : 'Delivery',
                  address,
                  multiline: true,
                ),
              ],
              if (!isPickup && estimatedDeliveryTime.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailRow(
                  context,
                  'ETA',
                  estimatedDeliveryTime,
                  valueColor: accent.withValues(alpha: 0.9),
                ),
              ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          PostCheckoutOrderItemsCard(
            items: items,
            accent: accent,
            animate: false,
            maxVisibleCollapsed: 3,
          ),
        ],
      ],
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
    bool multiline = false,
    bool highlight = false,
  }) {
    final valueWidget = Text(
      value,
      maxLines: multiline ? 5 : 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: bold ? 14 : 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: valueColor ?? PostCheckoutDesign.ink(context),
        height: 1.4,
      ),
    );

    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PostCheckoutDesign.muted(context),
            ),
          ),
        ),
        Expanded(
          child: highlight
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (valueColor ?? accent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: valueWidget,
                )
              : valueWidget,
        ),
      ],
    );
  }
}
