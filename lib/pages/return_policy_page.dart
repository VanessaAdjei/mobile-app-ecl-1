import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/policy/legal_policy_theme.dart';

/// Return & refund policy — layout aligned with [TermsAndConditionsPage].
class ReturnPolicyPage extends StatelessWidget {
  const ReturnPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final policy = LegalPolicyTheme.of(context);

    return Scaffold(
      backgroundColor: policy.pageBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const EclExpandableSliverAppBar(
            toolbarTitle: 'Return & Refund Policy',
            heroTitle: 'Returns & refunds',
            heroSubtitle:
                'Prescriptions, OTC products, and how to contact us',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _ReturnIntroCard(),
                const SizedBox(height: 20),
                _buildSection(
                  context,
                  '1',
                  'Refund Policy',
                  'We are pleased to assist. However, note that we do not offer payment refunds for any purchases. We may be able to facilitate an exchange for an alternative product if your item meets our return policy.',
                ),
                _buildSection(
                  context,
                  '2',
                  'Return Policy Overview',
                  'At ECL, your health and safety are our top priorities. Due to the sensitive nature of pharmaceutical products and strict health regulations, our return policy is designed to ensure the integrity of the medications and products we provide.',
                ),
                _buildSubSection(
                  context,
                  '2.1',
                  'Prescription medications',
                  '',
                  bulletPoints: [
                    'Prescription medications — no returns: We cannot accept returns for prescription medications once they have left the pharmacy.',
                  ],
                ),
                _buildSubSection(
                  context,
                  '2.2',
                  'Errors & defects',
                  '',
                  bulletPoints: [
                    'If you believe there has been an error in your prescription (e.g., incorrect medication or quantity) or if the product is damaged or defective upon receipt, please contact us within 24 hours.',
                    'We will investigate and, if verified, provide a replacement or refund at no additional cost.',
                  ],
                ),
                _buildSection(
                  context,
                  '3',
                  'OTC & general merchandise',
                  'Over-the-Counter (OTC) products and general merchandise (e.g., vitamins, bandages, beauty products, shavers, clippers, personal care items), you may return them within 24 hours of purchase under the following conditions:',
                ),
                _buildSubSection(
                  context,
                  '3.1',
                  'Conditions',
                  '',
                  bulletPoints: [
                    'Items must be unopened, in their original packaging and in the same condition as when purchased.',
                    'Proof of purchase: A valid receipt or proof of purchase is required for all returns and exchanges.',
                    'Non-returnable items: For safety and hygiene reasons, the following cannot be returned once opened: personal care items (e.g., thermometers, supports/braces, toothbrushes, shavers), baby formula and foods, items marked as "Reduce to clear".',
                    'For online orders, return shipping costs are the responsibility of the customer unless the item was sent in error.',
                  ],
                ),
                _buildSubSection(
                  context,
                  '3.2',
                  'How to initiate a return',
                  '',
                  bulletPoints: [
                    'In-store: Bring the item and your receipt to our customer service desk.',
                    'Online: Contact our support team at commerce@ecl.com.gh or WhatsApp on 0508411184 with your order number to receive a Return Authorization (RA) number.',
                  ],
                ),
                _buildSection(
                  context,
                  '4',
                  'Contact us',
                  'If you have any questions regarding our return policy, please reach out:',
                  bulletPoints: [
                    'Email: commerce@ecl.com.gh',
                    'Phone: 0302908674, 0302908675',
                    'WhatsApp: 0508411184',
                    'Address: Nester Square, 21 South Liberation Link, Airport City, Accra-Ghana',
                  ],
                ),
                const SizedBox(height: 12),
                _FooterStamp(year: year),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String number,
    String title,
    String content, {
    List<String>? bulletPoints,
  }) {
    final policy = LegalPolicyTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PolicySectionCard(
        policy: policy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionNumberBadge(number),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: policy.titleInk,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: policy.bodyText,
                  height: 1.65,
                ),
              ),
            ],
            if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BulletPanel(
                policy: policy,
                children:
                    bulletPoints.map((p) => _bulletRow(context, p)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubSection(
    BuildContext context,
    String number,
    String title,
    String content, {
    List<String>? bulletPoints,
  }) {
    final policy = LegalPolicyTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: policy.cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: policy.border),
            boxShadow: [
              BoxShadow(
                color: policy.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.85),
                        AppColors.primaryDark.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: policy.badgeTintBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                number,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: policy.badgeTintInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: policy.titleInk,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (content.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            content,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: policy.bodyText,
                              height: 1.6,
                            ),
                          ),
                        ],
                        if (bulletPoints != null &&
                            bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _BulletPanel(
                            policy: policy,
                            children: bulletPoints
                                .map((p) => _bulletRow(context, p, compact: true))
                                .toList(),
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
      ),
    );
  }

  Widget _bulletRow(
    BuildContext context,
    String point, {
    bool compact = false,
  }) {
    final policy = LegalPolicyTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: compact ? 6 : 7),
          child: Icon(
            Icons.fiber_manual_record,
            size: compact ? 7 : 8,
            color: policy.isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            point,
            style: GoogleFonts.poppins(
              fontSize: compact ? 13 : 14,
              color: policy.bodyText,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReturnIntroCard extends StatelessWidget {
  const _ReturnIntroCard();

  @override
  Widget build(BuildContext context) {
    final policy = LegalPolicyTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: policy.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: policy.border),
        boxShadow: [
          BoxShadow(
            color: policy.introShadow,
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            constraints: const BoxConstraints(minHeight: 88),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How returns work',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: policy.titleInk,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Prescription rules, OTC conditions, and ways to get help — summarized below for quick reference.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: policy.subtitleInk,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPanel extends StatelessWidget {
  const _BulletPanel({required this.policy, required this.children});

  final LegalPolicyTheme policy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: policy.bulletPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: policy.bulletPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({required this.policy, required this.child});

  final LegalPolicyTheme policy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: policy.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: policy.border),
          boxShadow: [
            BoxShadow(
              color: policy.cardShadow,
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionNumberBadge extends StatelessWidget {
  const _SectionNumberBadge(this.number);

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        number,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FooterStamp extends StatelessWidget {
  const _FooterStamp({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final policy = LegalPolicyTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Column(
          children: [
            Container(
              height: 1,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Document version · $year',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: policy.footerMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
