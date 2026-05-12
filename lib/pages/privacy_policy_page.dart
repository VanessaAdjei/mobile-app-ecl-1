import 'package:flutter/material.dart';

import '../widgets/ecl_expandable_sliver_app_bar.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5EDE8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const EclExpandableSliverAppBar(
            toolbarTitle: 'Privacy Statement',
            heroTitle: 'Your privacy',
            heroSubtitle: 'How we collect, use, and protect your data',
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
            _buildSection(
              '1.0',
              'Information We Collect',
              'We collect information you provide directly to us, including:',
              bulletPoints: [
                'Personal details (name, email, phone number)',
                'Delivery addresses',
                'Prescription images and health-related information',
                'Payment information',
                'Transaction history',
                'Device information and usage data',
              ],
            ),

            _buildSection(
              '2.0',
              'How We Use Your Information',
              'We use the information we collect to:',
              bulletPoints: [
                'Process and fulfill your orders',
                'Provide customer support and respond to inquiries',
                'Send notifications about your orders and deliveries',
                'Improve our services and user experience',
                'Ensure compliance with pharmaceutical regulations',
                'Prevent fraud and enhance security',
                'Communicate promotional offers (with your consent)',
              ],
            ),

            _buildSection(
              '3.0',
              'Location Data',
              'With your permission, we may collect and process your location data to:',
              bulletPoints: [
                'Help you find nearby stores and pharmacies',
                'Provide accurate delivery services',
                'Estimate delivery times',
                'Optimize our service coverage',
              ],
              additionalText:
                  'You can control location permissions through your device settings at any time.',
            ),

            _buildSection(
              '4.0',
              'Health Information',
              'Prescription and health-related information you provide is treated with strict confidentiality and used solely for processing your pharmaceutical orders. We comply with all applicable health information privacy laws and regulations, including the Data Protection Act, 2012 (Act 843).',
            ),

            _buildSection(
              '5.0',
              'Information Sharing',
              'We do not sell your personal information. We may share your information with:',
              bulletPoints: [
                'Service providers who assist in order fulfillment and delivery',
                'Payment processors to complete transactions',
                'Healthcare professionals for prescription verification (when required)',
                'Law enforcement or regulatory authorities (when legally required)',
                'Our affiliated pharmacies and stores',
              ],
              additionalText:
                  'All third parties are contractually obligated to protect your information and use it only for the purposes we specify.',
            ),

            _buildSection(
              '6.0',
              'Data Security',
              'We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. These measures include:',
              bulletPoints: [
                'Encryption of sensitive data',
                'Secure server infrastructure',
                'Regular security audits',
                'Access controls and authentication',
                'Employee training on data protection',
              ],
            ),

            _buildSection(
              '7.0',
              'Data Retention',
              'We retain your personal information for as long as necessary to fulfill the purposes outlined in this Privacy Statement, unless a longer retention period is required or permitted by law. Prescription records are retained in accordance with pharmaceutical regulations.',
            ),

            _buildSection(
              '8.0',
              'Your Rights',
              'Under the Data Protection Act, 2012 (Act 843), you have the right to:',
              bulletPoints: [
                'Access your personal information',
                'Request correction of inaccurate data',
                'Request deletion of your data (subject to legal requirements)',
                'Object to processing of your personal information',
                'Withdraw consent for data processing',
                'Lodge a complaint with the Data Protection Commission',
              ],
              additionalText:
                  'To exercise any of these rights, please contact us using the information provided below.',
            ),

            _buildSection(
              '9.0',
              'Cookies and Tracking',
              'Our app may use cookies and similar tracking technologies to enhance user experience and collect usage statistics. You can manage cookie preferences through your device settings.',
            ),

            _buildSection(
              '10.0',
              'Third-Party Services',
              'Our app may contain links to third-party services or integrate with external platforms. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies.',
            ),

            _buildSection(
              '11.0',
              'Children\'s Privacy',
              'Our services are not intended for individuals under the age of 18. We do not knowingly collect personal information from children. If we become aware that we have collected information from a child, we will take steps to delete such information.',
            ),

            _buildSection(
              '12.0',
              'Changes to This Policy',
              'We may update this Privacy Statement from time to time to reflect changes in our practices or legal requirements. We will notify you of any material changes through the app or via email. Continued use of our services after changes constitutes acceptance of the updated policy.',
            ),

            _buildSection(
              '13.0',
              'Data Protection Officer',
              'We have appointed a Data Protection Officer to oversee our privacy compliance. You may contact our DPO with any questions or concerns about how we handle your personal information.',
            ),

            _buildSection(
              '14.0',
              'International Data Transfers',
              'Your information may be transferred to and processed in countries outside Ghana. We ensure that appropriate safeguards are in place to protect your information in accordance with applicable data protection laws.',
            ),

            _buildSection(
              '15.0',
              'Compliance',
              'We are committed to complying with:',
              bulletPoints: [
                'Data Protection Act, 2012 (Act 843)',
                'Electronic Payment Act, 2019 (Act 987)',
                'Pharmacy Council Regulations',
                'Ghana National Electronic Pharmacy Platform (NEPP) requirements',
              ],
            ),

            _buildSection(
              '16.0',
              'Contact Information',
              'For questions, concerns, or requests regarding this Privacy Statement or our data practices, please contact us:',
              bulletPoints: [
                'Email: commerce@ecl.com.gh',
                'Phone: 0302908674, 0302908675',
                'WhatsApp: 0508411184',
                'Address: Nester Square, 21 south Liberation Link, Airport City, Accra-Ghana',
              ],
            ),

            _buildSection(
              '17.0',
              'Data Protection Commission',
              'You may also contact the Ghana Data Protection Commission:',
              bulletPoints: [
                'Website: www.dataprotection.org.gh',
                'Email: info@dataprotection.org.gh',
              ],
            ),

            SizedBox(height: 40),

            // Last updated
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last Updated: ${DateTime.now().year}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
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
    String? additionalText,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.6,
              ),
            ),
          ],
          if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
            SizedBox(height: 8),
            ...bulletPoints.map((point) => Padding(
                  padding: EdgeInsets.only(left: 16, top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (additionalText != null) ...[
            SizedBox(height: 8),
            Text(
              additionalText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
