// widgets/ecard_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ECardWidget extends StatefulWidget {
  final String cardNumber;
  final String cardHolderName;
  final double balance;
  final String currency;
  final String userEmail;
  final String userPhone;
  final VoidCallback? onTap;

  const ECardWidget({
    super.key,
    required this.cardNumber,
    required this.cardHolderName,
    required this.balance,
    required this.currency,
    required this.userEmail,
    required this.userPhone,
    this.onTap,
  });

  @override
  State<ECardWidget> createState() => _ECardWidgetState();
}

class _ECardWidgetState extends State<ECardWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _buildFrontCard(),
    );
  }

  Widget _buildFrontCard() {
    return Container(
      width: double.infinity,
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B5E20), // Darker Green
            Color(0xFF2E7D32), // Dark Green
            Color(0xFF4CAF50), // Green
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: ModernCardPatternPainter(),
            ),
          ),

          // Decorative elements
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE53935).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with logo and chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ECL Logo
                    Image.asset(
                      'assets/images/png.png',
                      height: 70,
                      width: 140,
                      fit: BoxFit.contain,
                    ),

                    // Modern chip
                    Container(
                      width: 35,
                      height: 25,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Card number with decorative background
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatCardNumber(widget.cardNumber),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // User info - clean layout
                Row(
                  children: [
                    // Left side - Name
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CARD HOLDER',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.cardHolderName.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right side - Contact info
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Email
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.userEmail,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Phone
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.userPhone,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  String _formatCardNumber(String cardNumber) {
    if (cardNumber.length < 16) {
      cardNumber = cardNumber.padRight(16, '*');
    }
    return cardNumber
        .replaceAllMapped(
          RegExp(r'.{4}'),
          (match) => '${match.group(0)} ',
        )
        .trim();
  }
}

class ModernCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Draw subtle geometric pattern
    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 8; j++) {
        final x = (i * size.width / 15) + (j % 2 == 0 ? 0 : size.width / 30);
        final y = (j * size.height / 8) + (i % 2 == 0 ? 0 : size.height / 16);

        // Draw small circles
        canvas.drawCircle(Offset(x, y), 1.0, paint);

        // Draw small squares
        if (i % 3 == 0 && j % 3 == 0) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 2, height: 2),
            paint,
          );
        }
      }
    }

    // Add some decorative lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Diagonal lines
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width * 0.4, 0),
      linePaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.6, size.height),
      Offset(size.width, size.height * 0.7),
      linePaint,
    );

    // Add some accent dots
    final accentPaint = Paint()
      ..color = const Color(0xFFE53935).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.2), 3, accentPaint);
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.8), 2, accentPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
