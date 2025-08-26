// pages/aboutus.dart
import 'package:flutter/material.dart';
import 'Cart.dart';
import 'app_back_button.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(children: [
      // Enhanced header with better design (matching notifications)
      Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top * 0.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade600,
              Colors.green.shade700,
              Colors.green.shade800,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                AppBackButton(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Us',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Learn about Ernest Chemists',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Cart(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // About Us content
      Expanded(
        child: Container(
          color: Colors.grey.shade50,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Simple Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.medical_services,
                            color: Colors.green.shade700,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ernest Chemists Limited',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Ghana\'s Leading Pharmaceutical Company',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSimpleCard(
                    title: 'Company Overview',
                    content:
                        'Ernest Chemists Limited (ECL) is the **biggest pharmaceutical company** in Ghana, driven by our mission to provide a full range of quality pharmaceutical products at affordable prices. With over **30 years of experience** in the Pharmaceutical Industry, Ernest Chemists Limited remains a true symbol of **stability and diversity**.',
                  ),

                  _buildSimpleCard(
                    title: 'Our History',
                    content:
                        'ECL is a wholly owned **Ghanaian company**, founded by Mr. **Ernest Bediako Sampong**, a pharmacist by profession, in the year **1986**. ECL has made giant strides since its commencement and has grown from a single retail outlet into a thriving business entity with our own **office complex**, **retail & wholesale shops**, **warehouse facilities** and **manufacturing plants**.',
                  ),

                  _buildSimpleCard(
                    title: 'Our Expertise',
                    content:
                        'We have deep insight, knowledge and experience in the pharmaceutical industry and this enables us to continue to provide **quality and affordable pharmaceutical products** to meet the health needs for everyone in the society. We have been able to consolidate our position as the **biggest distributor** of pharmaceutical products with a **wide distribution network** across Ghana and beyond.',
                  ),

                  // Services
                  _buildSimpleCard(
                    title: 'Our Services',
                    content:
                        'Aside the manufacturing of **quality and affordable medicine**, we also have the **biggest Agency representation** for **Multinational Pharmaceutical** and consumer brands which enables us to offer the **widest range** of pharmaceutical and consumer products in Ghana.',
                  ),

                  // Vision & Mission
                  _buildSimpleCard(
                    title: 'Vision & Mission',
                    content:
                        '**Our Vision:** To be a **leader** in the offering of **top quality pharmaceutical and healthcare products** in Africa.\n\n**Our Mission:** To provide a full range of **quality pharmaceutical products** at **affordable prices** with the view of **exceeding the expectations** of our valued customers and shareholders through a **highly motivated and efficient workforce** driven by **cutting edge technology**.',
                  ),

                  // Values
                  _buildValuesCard(
                    title: 'Our Values',
                    values: [
                      {
                        'icon': Icons.verified,
                        'text': 'Quality & Affordability'
                      },
                      {'icon': Icons.star, 'text': 'Customer Excellence'},
                      {
                        'icon': Icons.lightbulb,
                        'text': 'Innovation & Technology'
                      },
                      {'icon': Icons.shield, 'text': 'Integrity & Trust'},
                      {'icon': Icons.flag, 'text': 'Ghanaian Heritage'},
                      {'icon': Icons.work, 'text': 'Professional Excellence'},
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ]));
  }

  Widget _buildSimpleCard({
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            _buildFormattedText(content),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    // Split text by ** markers for bold formatting
    final parts = text.split('**');
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        if (parts[i].isNotEmpty) {
          widgets.add(
            Text(
              parts[i],
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
          );
        }
      } else {
        // Bold text with color
        if (parts[i].isNotEmpty) {
          widgets.add(
            Text(
              parts[i],
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
                height: 1.6,
              ),
            ),
          );
        }
      }
    }

    return RichText(
      text: TextSpan(
        children: widgets.map((widget) {
          if (widget is Text) {
            return TextSpan(
              text: widget.data,
              style: widget.style,
            );
          }
          return const TextSpan();
        }).toList(),
      ),
    );
  }

  Widget _buildValuesCard({
    required String title,
    required List<Map<String, dynamic>> values,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            ...values.map((value) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      value['icon'] as IconData,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value['text'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
