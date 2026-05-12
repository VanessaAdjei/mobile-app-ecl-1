import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

/// Return & refund policy — layout aligned with [TermsAndConditionsPage].
class ReturnPolicyPage extends StatelessWidget {
  const ReturnPolicyPage({super.key});

  static const Color _bodyText = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFFE5EDE8),
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
                  '1',
                  'Refund Policy',
                  'We are pleased to assist. However, note that we do not offer payment refunds for any purchases. We may be able to facilitate an exchange for an alternative product if your item meets our return policy.',
                ),
                _buildSection(
                  '2',
                  'Return Policy Overview',
                  'At ECL, your health and safety are our top priorities. Due to the sensitive nature of pharmaceutical products and strict health regulations, our return policy is designed to ensure the integrity of the medications and products we provide.',
                ),
                _buildSubSection(
                  '2.1',
                  'Prescription medications',
                  '',
                  bulletPoints: [
                    'Prescription medications — no returns: We cannot accept returns for prescription medications once they have left the pharmacy.',
                  ],
                ),
                _buildSubSection(
                  '2.2',
                  'Errors & defects',
                  '',
                  bulletPoints: [
                    'If you believe there has been an error in your prescription (e.g., incorrect medication or quantity) or if the product is damaged or defective upon receipt, please contact us within 24 hours.',
                    'We will investigate and, if verified, provide a replacement or refund at no additional cost.',
                  ],
                ),
                _buildSection(
                  '3',
                  'OTC & general merchandise',
                  'Over-the-Counter (OTC) products and general merchandise (e.g., vitamins, bandages, beauty products, shavers, clippers, personal care items), you may return them within 24 hours of purchase under the following conditions:',
                ),
                _buildSubSection(
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
                  '3.2',
                  'How to initiate a return',
                  '',
                  bulletPoints: [
                    'In-store: Bring the item and your receipt to our customer service desk.',
                    'Online: Contact our support team at commerce@ecl.com.gh or WhatsApp on 0508411184 with your order number to receive a Return Authorization (RA) number.',
                  ],
                ),
                _buildSection(
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
    String number,
    String title,
    String content, {
    List<String>? bulletPoints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PolicySectionCard(
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
                      color: const Color(0xFF111827),
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
                  color: _bodyText,
                  height: 1.65,
                ),
              ),
            ],
            if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BulletPanel(
                children:
                    bulletPoints.map((p) => _bulletRow(p)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubSection(
    String number,
    String title,
    String content, {
    List<String>? bulletPoints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                number,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
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
                                  color: const Color(0xFF1F2937),
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
                              color: _bodyText,
                              height: 1.6,
                            ),
                          ),
                        ],
                        if (bulletPoints != null &&
                            bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _BulletPanel(
                            children: bulletPoints
                                .map((p) => _bulletRow(p, compact: true))
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

  Widget _bulletRow(String point, {bool compact = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: compact ? 6 : 7),
          child: Icon(
            Icons.fiber_manual_record,
            size: compact ? 7 : 8,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            point,
            style: GoogleFonts.poppins(
              fontSize: compact ? 13 : 14,
              color: _bodyText,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.07),
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
                    color: const Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Prescription rules, OTC conditions, and ways to get help — summarized below for quick reference.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
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
  const _BulletPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEEE4)),
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
  const _PolicySectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5EBE7)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
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
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
