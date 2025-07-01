// pages/pharmacists.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'AppBackButton.dart';
import '../widgets/cart_icon_button.dart';

class PharmacistsPage extends StatelessWidget {
  const PharmacistsPage({Key? key}) : super(key: key);

  void _showContactOptions(BuildContext context, String phoneNumber) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.call, color: Colors.green),
                title: Text('Call'),
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _launchPhoneDialer(phoneNumber);
                },
              ),
              ListTile(
                leading:
                    FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                title: Text('WhatsApp'),
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _launchWhatsApp(phoneNumber,
                      "Hello, I'd like to speak with a pharmacist.");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchPhoneDialer(String phoneNumber) async {
    final Uri callUri = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  void _launchWhatsApp(String phoneNumber, String message) async {
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+233${phoneNumber.substring(1)}';
    }
    String whatsappUrl =
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}';
    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade800,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meet Our Pharmacists',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildPharmacistCard(
            context,
            name: 'Dr. Sarah Mensah',
            qualification: 'PharmD, MPS',
            specialization: 'Clinical Pharmacy',
            experience: '15 years',
            imageUrl: 'assets/images/pharmacist1.jpg',
            phoneNumber: '+233504518047',
          ),
          SizedBox(height: 16),
          _buildPharmacistCard(
            context,
            name: 'Dr. Kwame Osei',
            qualification: 'PharmD, PhD',
            specialization: 'Pharmaceutical Research',
            experience: '12 years',
            imageUrl: 'assets/images/pharmacist2.jpg',
            phoneNumber: '+233504518047',
          ),
          SizedBox(height: 16),
          _buildPharmacistCard(
            context,
            name: 'Dr. Ama Kufuor',
            qualification: 'PharmD, MPH',
            specialization: 'Public Health Pharmacy',
            experience: '10 years',
            imageUrl: 'assets/images/pharmacist3.jpg',
            phoneNumber: '+233504518047',
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacistCard(
    BuildContext context, {
    required String name,
    required String qualification,
    required String specialization,
    required String experience,
    required String imageUrl,
    required String phoneNumber,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: Icon(Icons.person, size: 80, color: Colors.grey[400]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  qualification,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                _buildInfoRow(Icons.medical_services_outlined, specialization),
                SizedBox(height: 8),
                _buildInfoRow(Icons.work_outline, '$experience Experience'),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showContactOptions(context, phoneNumber),
                  icon: Icon(Icons.contact_phone),
                  label: Text('Contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
