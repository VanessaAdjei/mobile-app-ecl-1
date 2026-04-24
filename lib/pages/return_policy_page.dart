import 'package:flutter/material.dart';

class ReturnPolicyPage extends StatelessWidget {
  const ReturnPolicyPage({super.key});

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
          'Return & Refund Policy',
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
              'Refund Policy',
              'We are pleased to assist. However, note that we do not offer payment refunds for any purchases. We may be able to facilitate an exchange for an alternative product if your item meets our return policy.',
            ),

            _buildSection(
              'Return Policy Overview',
              'At ECL, your health and safety are our top priorities. Due to the sensitive nature of pharmaceutical products and strict health regulations, our return policy is designed to ensure the integrity of the medications and products we provide.',
            ),

            _buildSubSection(
              'Prescription Orders',
              'Prescription Medications - No Returns',
              bulletPoints: [
                'We cannot accept returns for prescription medications once they have left the pharmacy.',
              ],
            ),

            _buildSubSection(
              '',
              'Errors & Defects',
              bulletPoints: [
                'If you believe there has been an error in your prescription (e.g., incorrect medication or quantity) or if the product is damaged/defective upon receipt, please contact us within 24 hours.',
                'We will investigate and, if verified, provide a replacement or refund at no additional cost.',
              ],
            ),

            _buildSection(
              'OTC & General Merchandise',
              'Over-the-Counter (OTC) Products & General Merchandise (e.g., vitamins, bandages, beauty products, shavers, clippers, personal care items etc.), you may return them within 24 hours of purchase under the following conditions:',
            ),

            _buildSubSection(
              '',
              'Conditions',
              bulletPoints: [
                'Items must be unopened, in their original packaging and in the same condition as when purchased.',
                'Proof of Purchase: A valid receipt or proof of purchase is required for all returns and exchanges.',
                'Non-Returnable Items: For safety and hygiene reasons, the following cannot be returned once opened: Personal care items (e.g., thermometers, supports/braces, toothbrushes, shavers), Baby formula and foods, Items marked as "Reduce to clear".',
                'For online orders, return shipping costs are the responsibility of the customer unless the item was sent in error.',
              ],
            ),

            _buildSubSection(
              '',
              'How to Initiate a Return',
              bulletPoints: [
                'In-Store: Bring the item and your receipt to our customer service desk.',
                'Online: Contact our support team at commerce@ecl.com.gh or WhatsApp on 0508411184 with your order number to receive a Return Authorization (RA) number.',
              ],
            ),

            _buildSection(
              'Contact Us',
              'If you have any questions regarding our return policy, please reach out:',
              bulletPoints: [
                'Email: commerce@ecl.com.gh',
                'Phone: 0302908674, 0302908675',
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
    String title,
    String content, {
    List<String>? bulletPoints,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
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
            SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildSubSection(
    String subtitle,
    String title, {
    List<String>? bulletPoints,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
            ),
            SizedBox(height: 8),
          ],
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(height: 8),
          ],
          if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
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
