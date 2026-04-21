import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Color(0xFF4CAF50),
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1.0',
              'Introduction',
              'Welcome to your trusted partner in health, your provider of quality and affordable medicines through modern convenient platform.\n\nBy accessing or using our platform, you agree to comply with the Terms & Conditions associated with it. If you have any concerns about these terms, you may wish to discontinue use of this platform.',
            ),

            _buildSection(
              '2.0',
              'Purpose of the Platform',
              'We are dedicated to providing you with a seamless experience, offering a comprehensive selection of prescription medications, over-the-counter essentials, premium wellness products, personal care products, home and hygiene products and several others delivered directly to your door.\n\nOur commitment to safety and authenticity means every order is handled by our team of professionals, ensuring you have the support and guidance you need.',
            ),

            _buildSection(
              '3.0',
              'Eligibility',
              'Use of this platform is restricted to individuals who are at least 18 years old and capable of entering into legally binding agreements. Users are required to provide accurate personal, medical, and delivery information and to ensure that all details submitted remain up to date. The platform reserves the right to verify user information and take appropriate action where discrepancies are identified.',
            ),

            _buildSection(
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
              '5.0',
              'Product Information',
              'We strive to ensure all product descriptions, prices and images are accurate. However, in some instances products and packaging may differ from displayed images.',
            ),

            _buildSection(
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
              '9.0',
              'Refund, Return & Cancellation Policy',
              '',
            ),

            _buildSubSection(
              '9.1',
              'Refund',
              'We are pleased to assist. However, note that we do not offer payment refunds for any purchases. We may be able to facilitate an exchange for an alternative product if your item meets our return policy.',
            ),

            _buildSubSection(
              '9.2',
              'Return Policy',
              'At ECL, your health and safety are our top priorities. Due to the sensitive nature of pharmaceutical products and strict health regulations, our return policy is designed to ensure the integrity of the medications and products we provide.',
            ),

            _buildSubSection(
              '9.2.1',
              'Prescription Orders',
              '',
              bulletPoints: [
                'Prescription Medications, No Returns: We cannot accept returns for prescription medications once they have left the pharmacy.',
                'Errors & Defects: If you believe there has been an error in your prescription (e.g., incorrect medication or quantity) or if the product is damaged/defective upon receipt, please contact us within 24 hours. We will investigate and, if verified, provide a replacement or refund at no additional cost.',
              ],
            ),

            _buildSubSection(
              '9.2.2',
              'OTC & General Merchandise',
              'Over-the-Counter (OTC) Products & General Merchandise (e.g., vitamins, bandages, beauty products, shavers, clippers, personal care items etc.), you may return them within 24 hours of purchase under the following conditions.\n\nConditions:',
              bulletPoints: [
                'Items must be unopened, in their original packaging and in the same condition as when purchased.',
                'Proof of Purchase: A valid receipt or proof of purchase is required for all returns and exchanges.',
                'Non-Returnable Items: For safety and hygiene reasons, the following cannot be returned once opened, Personal care items (e.g., thermometers, supports/braces, toothbrushes, shavers). Baby formula and foods. Items marked as "Reduce to clear".',
                'For online orders, return shipping costs are the responsibility of the customer unless the item was sent in error.',
                'How to Initiate a Return In-Store: Bring the item and your receipt to our customer service desk.',
                'Online: Contact our support team at info@ecl.com.gh or WhatsApp on 0508411184 with your order number to receive a Return Authorization (RA) number.',
              ],
            ),

            _buildSubSection(
              '9.2.3',
              'Cancellation Policy',
              'Users are encouraged to review their orders carefully before confirming purchase to avoid the need for cancellations. Once an order has been successfully placed, the platform begins processing it promptly to ensure timely delivery; therefore, there may be a limited window within which cancellations can be accommodated.\n\nIf a user wishes to cancel an order, the request must be submitted through the appropriate customer service channels as soon as possible. The platform will make reasonable efforts to process such requests, but cannot guarantee cancellation if the order has already entered the dispatch stage.\n\nPlease note that once an order has been shipped or handed over to a delivery service provider, it can no longer be cancelled. In such cases, the order will be treated as completed and will fall under the platform\'s return and refund policy, where applicable. The platform reserves the right to decline cancellation requests that do not meet these conditions.',
            ),

            _buildSection(
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
              '11.0',
              'Intellectual Property',
              '',
              bulletPoints: [
                'All website content (logos, text, images) is protected.',
                'Users may not copy, distribute, or reuse content without express permission',
              ],
            ),

            _buildSection(
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
              '16.0',
              'Account Suspension',
              'We reserve the right to:',
              bulletPoints: [
                'Suspend or terminate accounts for violations',
                'Cancel fraudulent or suspicious orders',
              ],
            ),

            _buildSection(
              '18.0',
              'Amendments',
              'We may update these Terms at any time without prior notice.\n\nContinued use of the platform constitutes acceptance of updates.',
            ),

            _buildSection(
              '20.0',
              'Contact Information',
              'For support, complaints, or inquiries:',
              bulletPoints: [
                'Email: info@ecl.com.gh',
                'Phone: (+233) 302 908674/5',
                'WhatsApp: 0508411184',
                'Address: Nester Square, 21 south Liberation Link, Airport City, Accra-Ghana',
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

            SizedBox(height: 20),
          ],
        ),
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
              ),
            ),
          ],
        ],
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
      padding: EdgeInsets.only(left: 20, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            SizedBox(height: 8),
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
            SizedBox(height: 6),
            ...bulletPoints.map((point) => Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Color(0xFF66BB6A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
