import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAcceptancePage extends StatefulWidget {
  const TermsAcceptancePage({super.key});

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isLoading = false;

  Future<void> _launchDataProtectionUrl() async {
    final url = Uri.parse('https://dataprotection.org.gh/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the website'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptAndContinue() async {
    if (!_termsAccepted || !_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please accept both Terms & Conditions and Privacy Policy to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terms_accepted', true);
      await prefs.setString(
          'terms_accepted_date', DateTime.now().toIso8601String());

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTermsDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF4CAF50),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Terms & Conditions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please read these terms carefully before using our services',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildDialogSection(
                  Icons.check_circle_outline,
                  '1. Acceptance of Terms',
                  'By accessing and using this mobile application, you accept and agree to be bound by the terms and provision of this agreement.',
                ),
                _buildDialogSection(
                  Icons.vpn_key_outlined,
                  '2. Use License',
                  'Permission is granted to temporarily download one copy of the materials on Ernest Chemists Limited\'s mobile application for personal, non-commercial transitory viewing only.',
                ),
                _buildDialogSection(
                  Icons.person_outline,
                  '3. User Account',
                  'You may be required to create an account to access certain features. You are responsible for maintaining the confidentiality of your account credentials.',
                ),
                _buildDialogSection(
                  Icons.inventory_2_outlined,
                  '4. Product Information',
                  'We strive to provide accurate product information. However, we do not warrant that product descriptions or other content is accurate, complete, reliable, current, or error-free.',
                ),
                _buildDialogSection(
                  Icons.payment_outlined,
                  '5. Pricing and Payment',
                  'All prices are subject to change without notice. Payment must be received by us before your order is processed.',
                ),
                _buildDialogSection(
                  Icons.medical_services_outlined,
                  '6. Prescription Uploads',
                  'When uploading prescriptions, you agree that the prescription is valid and issued by a licensed healthcare provider.',
                ),
                _buildDialogSection(
                  Icons.copyright_outlined,
                  '7. Intellectual Property',
                  'This application and its original content, features, and functionality are owned by Ernest Chemists Limited and are protected by international copyright, trademark, and other intellectual property laws.',
                ),
                _buildDialogSection(
                  Icons.shield_outlined,
                  '8. Limitation of Liability',
                  'Ernest Chemists Limited shall not be liable for any damages arising from the use or inability to use this application.',
                ),
                _buildDialogSection(
                  Icons.update_outlined,
                  '9. Changes to Terms',
                  'We reserve the right to modify these terms at any time. Continued use of the application after changes constitutes acceptance of the new terms.',
                ),
                _buildDialogSection(
                  Icons.contact_support_outlined,
                  '10. Contact Information',
                  'For questions about these Terms, please contact us through the app or visit our website.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Last updated: April 2026',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF4CAF50),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Privacy Policy',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your privacy is important to us. Learn how we protect your data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDialogSection(
                  Icons.folder_outlined,
                  '1. Information We Collect',
                  'We collect information you provide directly to us, including name, email, phone number, delivery address, and prescription images.',
                ),
                _buildDialogSection(
                  Icons.analytics_outlined,
                  '2. How We Use Your Information',
                  'We use the information we collect to process orders, provide customer support, send notifications about your orders, and improve our services.',
                ),
                _buildDialogSection(
                  Icons.location_on_outlined,
                  '3. Location Data',
                  'With your permission, we may collect your location data to help you find nearby stores and provide accurate delivery services.',
                ),
                _buildDialogSection(
                  Icons.health_and_safety_outlined,
                  '4. Health Information',
                  'Prescription and health-related information you provide is treated with strict confidentiality and used solely for processing your pharmaceutical orders.',
                ),
                _buildDialogSection(
                  Icons.share_outlined,
                  '5. Information Sharing',
                  'We do not sell your personal information. We may share your information with service providers who assist in order fulfillment and delivery.',
                ),
                _buildDialogSection(
                  Icons.lock_outlined,
                  '6. Data Security',
                  'We implement security measures to protect your personal information. However, no method of transmission over the internet is 100% secure.',
                ),
                _buildDialogSection(
                  Icons.verified_user_outlined,
                  '7. Your Rights',
                  'You have the right to access, update, or delete your personal information. Contact us through the app to exercise these rights.',
                ),
                _buildDialogSection(
                  Icons.cookie_outlined,
                  '8. Cookies and Tracking',
                  'We may use cookies and similar technologies to improve your experience and analyze app usage.',
                ),
                _buildDialogSection(
                  Icons.child_care_outlined,
                  '9. Children\'s Privacy',
                  'Our services are not intended for children under 13. We do not knowingly collect information from children under 13.',
                ),
                _buildDialogSection(
                  Icons.update_outlined,
                  '10. Changes to Privacy Policy',
                  'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy in the app.',
                ),
                _buildDialogSection(
                  Icons.contact_mail_outlined,
                  '11. Contact Us',
                  'If you have questions about this Privacy Policy, please contact us through the app or visit our website.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Last updated: April 2026',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _launchDataProtectionUrl,
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new,
                                color: const Color(0xFF4CAF50), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Ghana Data Protection Commission',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
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
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogSection(IconData icon, String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/images/png.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      'Welcome to Ernest Chemists Limited',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Before you get started, please review and accept our terms',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Terms Checkbox
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _termsAccepted
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade300,
                          width: _termsAccepted ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _termsAccepted,
                            activeColor: const Color(0xFF4CAF50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _termsAccepted = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I accept the '),
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: const TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showTermsDialog,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Privacy Checkbox
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _privacyAccepted
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade300,
                          width: _privacyAccepted ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _privacyAccepted,
                            activeColor: const Color(0xFF4CAF50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _privacyAccepted = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I accept the '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showPrivacyDialog,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Link to Ghana Data Protection Commission
                    Center(
                      child: GestureDetector(
                        onTap: _launchDataProtectionUrl,
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            children: [
                              const TextSpan(
                                  text:
                                      'Learn more about your data rights at\n'),
                              TextSpan(
                                text: 'Ghana Data Protection Commission',
                                style: const TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _acceptAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Accept & Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
