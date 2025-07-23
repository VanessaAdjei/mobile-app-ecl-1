// pages/clickableimage.dart
import 'package:eclapp/pages/prescription.dart';
import 'package:flutter/material.dart';

class ClickableImageButton extends StatelessWidget {
  final String imageUrl = 'assets/images/prescription.png';

  const ClickableImageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.green.withValues(alpha: 0.18),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PrescriptionUploadPage(token: '')),
            );
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.green.shade100,
          highlightColor: Colors.green.shade50,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 120),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade800,
                  Colors.green.shade600,
                  Colors.green.shade400
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.13),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 30,
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Submit Prescription',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
