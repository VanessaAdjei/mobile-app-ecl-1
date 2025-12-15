// widgets/animated_map_pin.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class AnimatedMapPin extends StatefulWidget {
  final LatLng position;
  final String markerId;
  final String title;
  final String snippet;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color pinColor;
  final Color pulseColor;
  final IconData? icon;

  const AnimatedMapPin({
    super.key,
    required this.position,
    required this.markerId,
    required this.title,
    this.snippet = '',
    this.isSelected = false,
    this.onTap,
    this.pinColor = Colors.red,
    this.pulseColor = Colors.red,
    this.icon,
  });

  @override
  State<AnimatedMapPin> createState() => _AnimatedMapPinState();
}

class _AnimatedMapPinState extends State<AnimatedMapPin>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _scaleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for selected pins
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // bounce animation for pin appearance
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale animation for tap feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // start animations
    _bounceController.forward();

    if (widget.isSelected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedMapPin oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimation,
        _bounceAnimation,
        _scaleAnimation,
      ]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // pulse effect for selected pins
            if (widget.isSelected)
              Transform.scale(
                scale: 1.0 + (_pulseAnimation.value * 0.5),
                child: Opacity(
                  opacity: 1.0 - _pulseAnimation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.pulseColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),

            // main pin with bounce animation
            Transform.scale(
              scale: _bounceAnimation.value * _scaleAnimation.value,
              child: GestureDetector(
                onTap: _onTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.pinColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.pinColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon ?? Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// custom marker widget for google maps
class CustomAnimatedMarker {
  static Future<BitmapDescriptor> createAnimatedMarker({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
    double size = 50.0,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // make a circular background
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // make a border
    final Paint borderPaint = Paint()
      ..color = backgroundColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw the circular background
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      backgroundPaint,
    );

    // draw the border
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Draw the icon
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.4,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}

// animated marker manager for handling multiple pins
class AnimatedMarkerManager {
  static Set<Marker> createAnimatedMarkers({
    required List<Map<String, dynamic>> locations,
    required String selectedMarkerId,
    required Function(String) onMarkerTap,
    Color defaultColor = Colors.red,
    Color selectedColor = Colors.blue,
  }) {
    return locations.map((location) {
      final markerId = location['id']?.toString() ?? '';
      final isSelected = markerId == selectedMarkerId;

      return Marker(
        markerId: MarkerId(markerId),
        position: LatLng(
          location['lat'] ?? 0.0,
          location['lng'] ?? 0.0,
        ),
        infoWindow: InfoWindow(
          title: location['title'] ?? '',
          snippet: location['snippet'] ?? '',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
        ),
        onTap: () => onMarkerTap(markerId),
      );
    }).toSet();
  }
}

// pulse animation widget for map pins
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Color pulseColor;
  final Duration duration;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.pulseColor = Colors.red,
    this.duration = const Duration(milliseconds: 1500),
    this.maxScale = 1.5,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // pulse effect
            Transform.scale(
              scale: 1.0 + (_animation.value * (widget.maxScale - 1.0)),
              child: Opacity(
                opacity: 1.0 - _animation.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.pulseColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            // main widget
            widget.child,
          ],
        );
      },
    );
  }
}
