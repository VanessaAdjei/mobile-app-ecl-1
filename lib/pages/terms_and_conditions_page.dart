import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/policy/legal_policy_theme.dart';

/// Full Terms & Conditions — readable layout with section cards.
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

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
            toolbarTitle: 'Terms & Conditions',
            heroTitle: 'Your agreement',
            heroSubtitle: 'Policies for using our pharmacy platform',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _IntroSummaryCard(),
                const SizedBox(height: 20),
                _buildSection(
                  context,
                  '1.0',
                  'Introduction',
                  'Welcome to your trusted partner in health, your provider of quality and affordable medicines through modern convenient platform.\n\nBy accessing or using our platform, you agree to comply with the Terms & Conditions associated with it. If you have any concerns about these terms, you may wish to discontinue use of this platform.',
                ),
                _buildSection(
                  context,
                  '2.0',
                  'Purpose of the Platform',
                  'We are dedicated to providing you with a seamless experience, offering a comprehensive selection of prescription medications, over-the-counter essentials, premium wellness products, personal care products, home and hygiene products and several others delivered directly to your door.\n\nOur commitment to safety and authenticity means every order is handled by our team of professionals, ensuring you have the support and guidance you need.',
                ),
                _buildSection(
                  context,
                  '3.0',
                  'Eligibility',
                  'Use of this platform is restricted to individuals who are at least 18 years old and capable of entering into legally binding agreements. Users are required to provide accurate personal, medical, and delivery information and to ensure that all details submitted remain up to date. The platform reserves the right to verify user information and take appropriate action where discrepancies are identified.',
                ),
                _buildSection(
                  context,
                  '4.0',
                  'Prescription Policy',
                  'Prescription-only medicines require a valid prescription from a licensed healthcare professional. The platform reserves the right to:',
                  bulletPoints: [
                    'Verify prescriptions',
                    'Reject invalid or expired prescriptions',
                    'Cancel orders without proper documentation',
                  ],
                ),
                _buildSection(
                  context,
                  '5.0',
                  'Product Information',
                  'We strive to ensure all product descriptions, prices and images are accurate. However, in some instances products and packaging may differ from displayed images.',
                ),
                _buildSection(
                  context,
                  '6.0',
                  'Medical Disclaimer',
                  '',
                  bulletPoints: [
                    'Information provided is for educational purposes only.',
                    'It does NOT replace professional medical advice.',
                    'Always consult your Pharmacist or a qualified healthcare provider before using any medication.',
                  ],
                ),
                _buildSection(
                  context,
                  '7.0',
                  'Orders and Payments',
                  'Orders are subject to:',
                  bulletPoints: [
                    'Product availability',
                    'Payment confirmation',
                  ],
                  additionalText:
                      'We reserve the right to:\n• Refuse or cancel any order\n• Revise quantities purchased\n• Payment must be made through approved methods.',
                ),
                _buildSection(
                  context,
                  '8.0',
                  'Delivery Policy',
                  'Delivery timelines are estimates and may vary due to:',
                  bulletPoints: [
                    'Location',
                    'Weather conditions',
                    'Third-party courier delays',
                    'Natural Disasters',
                    'Risk transfers to the customer upon delivery.',
                  ],
                ),
                _buildSection(
                  context,
                  '9.0',
                  'Refund, Return & Cancellation Policy',
                  '',
                ),
                _buildSubSection(
                  context,
                  '9.1',
                  'Refund',
                  'We are pleased to assist. However, note that we do not offer payment refunds for any purchases. We may be able to facilitate an exchange for an alternative product if your item meets our return policy.',
                ),
                _buildSubSection(
                  context,
                  '9.2',
                  'Return Policy',
                  'At ECL, your health and safety are our top priorities. Due to the sensitive nature of pharmaceutical products and strict health regulations, our return policy is designed to ensure the integrity of the medications and products we provide.',
                ),
                _buildSubSection(
                  context,
                  '9.2.1',
                  'Prescription Orders',
                  '',
                  bulletPoints: [
                    'Prescription Medications, No Returns: We cannot accept returns for prescription medications once they have left the pharmacy.',
                    'Errors & Defects: If you believe there has been an error in your prescription (e.g., incorrect medication or quantity) or if the product is damaged/defective upon receipt, please contact us within 24 hours. We will investigate and, if verified, provide a replacement or refund at no additional cost.',
                  ],
                ),
                _buildSubSection(
                  context,
                  '9.2.2',
                  'OTC & General Merchandise',
                  'Over-the-Counter (OTC) Products & General Merchandise (e.g., vitamins, bandages, beauty products, shavers, clippers, personal care items etc.), you may return them within 24 hours of purchase under the following conditions.\n\nConditions:',
                  bulletPoints: [
                    'Items must be unopened, in their original packaging and in the same condition as when purchased.',
                    'Proof of Purchase: A valid receipt or proof of purchase is required for all returns and exchanges.',
                    'Non-Returnable Items: For safety and hygiene reasons, the following cannot be returned once opened, Personal care items (e.g., thermometers, supports/braces, toothbrushes, shavers). Baby formula and foods. Items marked as "Reduce to clear".',
                    'For online orders, return shipping costs are the responsibility of the customer unless the item was sent in error.',
                    'How to Initiate a Return In-Store: Bring the item and your receipt to our customer service desk.',
                    'Online: Contact our support team at commerce@ecl.com.gh or WhatsApp on 0508411184 with your order number to receive a Return Authorization (RA) number.',
                  ],
                ),
                _buildSubSection(
                  context,
                  '9.2.3',
                  'Cancellation Policy',
                  'Users are encouraged to review their orders carefully before confirming purchase to avoid the need for cancellations. Once an order has been successfully placed, the platform begins processing it promptly to ensure timely delivery; therefore, there may be a limited window within which cancellations can be accommodated.\n\nIf a user wishes to cancel an order, the request must be submitted through the appropriate customer service channels as soon as possible. The platform will make reasonable efforts to process such requests, but cannot guarantee cancellation if the order has already entered the dispatch stage.\n\nPlease note that once an order has been shipped or handed over to a delivery service provider, it can no longer be cancelled. In such cases, the order will be treated as completed and will fall under the platform\'s return and refund policy, where applicable. The platform reserves the right to decline cancellation requests that do not meet these conditions.',
                ),
                _buildSection(
                  context,
                  '10.0',
                  'User Responsibilities',
                  'Users agree to:',
                  bulletPoints: [
                    'Provide accurate details',
                    'Use medicines responsibly',
                    'Follow prescription and dosage instructions',
                    'Inspect products at the point of delivery',
                    'Make full payment for request to be considered as confirmed order',
                  ],
                ),
                _buildSection(
                  context,
                  '11.0',
                  'Intellectual Property',
                  '',
                  bulletPoints: [
                    'All website content (logos, text, images) is protected.',
                    'Users may not copy, distribute, or reuse content without express permission',
                  ],
                ),
                _buildSection(
                  context,
                  '12.0',
                  'Privacy & Data Protection',
                  'User data is handled in accordance with:\n• Data Protection Act and Electronic Payment Act 2019 (987)\n• Management of sensitive health and personal information in compliance with the Data Protection Act, 2012 (843).\n\nInformation collected includes:',
                  bulletPoints: [
                    'Personal details',
                    'Medical prescriptions',
                    'Transaction history',
                  ],
                ),
                _buildSection(
                  context,
                  '13.0',
                  'Limitation of Liability',
                  'We are not liable for:',
                  bulletPoints: [
                    'Incorrect use of medicines',
                    'Delays caused by third parties and wrong delivery details or location and untimely response to communication.',
                    'Natural disasters',
                    'Losses due to website downtime',
                    'Liability is limited to the value of the purchased product.',
                  ],
                ),
                _buildSection(
                  context,
                  '14.0',
                  'Compliance with Laws',
                  'The platform operates in accordance with:',
                  bulletPoints: [
                    'Pharmacy Council Regulations',
                    'Ghana National Electronic Pharmacy Platform (NEPP)',
                    'Public health laws',
                  ],
                ),
                _buildSection(
                  context,
                  '15.0',
                  'Prohibited Activities',
                  'Users must NOT:',
                  bulletPoints: [
                    'Misuse prescriptions',
                    'Engage in fraudulent transactions',
                    'Attempt to hack or disrupt the platform',
                    'Resell medicines purchased on this platform',
                  ],
                ),
                _buildSection(
                  context,
                  '16.0',
                  'Account Suspension',
                  'We reserve the right to:',
                  bulletPoints: [
                    'Suspend or terminate accounts for violations',
                    'Cancel fraudulent or suspicious orders',
                  ],
                ),
                _buildSection(
                  context,
                  '18.0',
                  'Amendments',
                  'We may update these Terms at any time without prior notice.\n\nContinued use of the platform constitutes acceptance of updates.',
                ),
                _buildSection(
                  context,
                  '20.0',
                  'Contact Information',
                  'For support, complaints, or inquiries:',
                  bulletPoints: [
                    'Email: commerce@ecl.com.gh',
                    'Phone: 0302908674, 0302908675',
                    'WhatsApp: 0508411184',
                    'Address: Nester Square, 21 south Liberation Link, Airport City, Accra-Ghana',
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
    String? additionalText,
  }) {
    final policy = LegalPolicyTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SectionCard(
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
                children: bulletPoints
                    .map((p) => _bulletRow(context, p))
                    .toList(),
              ),
            ],
            if (additionalText != null) ...[
              const SizedBox(height: 10),
              Text(
                additionalText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: policy.bodyText,
                  height: 1.65,
                ),
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

class _IntroSummaryCard extends StatelessWidget {
  const _IntroSummaryCard();

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
                  'Please read carefully',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: policy.titleInk,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'By using Ernest Chemists Limited services you agree to these terms. The sections below explain how our platform works, your responsibilities, and our policies.',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.policy, required this.child});

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
