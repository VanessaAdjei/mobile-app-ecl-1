import 'package:flutter/material.dart';

import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_utils.dart';
import 'payment_section_style.dart';

/// One continuous surface for delivery, items, and bill on the payment page.
class PaymentCheckoutSheet extends StatelessWidget {
  const PaymentCheckoutSheet({
    super.key,
    required this.sections,
  });

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final horizontal = ResponsiveUtils.pageHorizontalPadding(context);
    final radius = PaymentSectionStyle.radiusOf(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontal),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(radius + 4),
        border: Border.all(color: t.border.withValues(alpha: 0.55)),
        boxShadow: t.isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PaymentSectionStyle.sectionDivider(context),
              ),
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.scaled(context, 16)),
              child: sections[i],
            ),
          ],
        ],
      ),
    );
  }
}
