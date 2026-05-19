import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/order_tracking_model.dart';
import '../services/location_service.dart';
import '../utils/non_ui_error_reporter.dart';

/// Default center when address cannot be geocoded (Accra, Ghana). Also used as default shop location.
const LatLng _defaultCenter = LatLng(5.6037, -0.1870);
const double _defaultZoom = 12.0;

/// Full-screen map for track order page. Uses Google Maps.
/// When [showShopLocation] is false (home delivery), only the customer's delivery point is shown.
class TrackingMap extends StatefulWidget {
  const TrackingMap({
    super.key,
    required this.order,
    this.height,
    this.accent,
    this.shopCoordinates,
    this.deliveryCoordinates,
    /// Optional shop/store address to geocode. If null, a default location (Accra) is used.
    this.shopAddress,
    this.showShopLocation = true,
    this.destinationMarkerTitle = 'Delivery address',
  });

  final OrderTrackingModel order;
  final double? height;
  final Color? accent;
  final LatLng? shopCoordinates;
  final LatLng? deliveryCoordinates;
  final String? shopAddress;
  final bool showShopLocation;
  final String destinationMarkerTitle;

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  LatLng? _shopPosition;
  LatLng? _deliveryPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Show map immediately with default markers so the map is visible; geocode in background
    setState(() {
      _shopPosition = widget.showShopLocation ? _defaultCenter : null;
      _deliveryPosition = _defaultCenter;
      _markers = _buildMarkers(
        shop: widget.showShopLocation ? _defaultCenter : null,
        delivery: _defaultCenter,
        shopSnippet: widget.shopAddress,
      );
    });
    _geocodeAndUpdateMap();
  }

  Set<Marker> _buildMarkers({
    required LatLng? shop,
    required LatLng delivery,
    String? shopSnippet,
  }) {
    final deliveryAddress = widget.order.deliveryAddress;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('delivery'),
        position: delivery,
        infoWindow: InfoWindow(
          title: widget.destinationMarkerTitle,
          snippet: deliveryAddress.isNotEmpty ? deliveryAddress : 'Delivery point',
        ),
      ),
    };
    if (widget.showShopLocation && shop != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('shop'),
          position: shop,
          infoWindow: InfoWindow(
            title: 'Shop',
            snippet: shopSnippet?.isNotEmpty == true ? shopSnippet : 'ECL Store',
          ),
        ),
      );
    }
    return markers;
  }

  Future<void> _geocodeAndUpdateMap() async {
    final deliveryAddress = widget.order.deliveryAddress;
    final shopAddress = widget.shopAddress;

    try {
      final locationService = LocationService();

      LatLng? shop;
      if (widget.showShopLocation) {
        shop = widget.shopCoordinates ?? _defaultCenter;
        if (widget.shopCoordinates == null &&
            shopAddress != null &&
            shopAddress.trim().isNotEmpty) {
          final coords =
              await locationService.getCoordinatesFromAddress(shopAddress.trim());
          if (coords != null) {
            shop = LatLng(coords['lat']!, coords['lon']!);
          }
        }
      }

      LatLng delivery = widget.deliveryCoordinates ?? _defaultCenter;
      if (widget.deliveryCoordinates == null && deliveryAddress.trim().isNotEmpty) {
        final coords =
            await locationService.getCoordinatesFromAddress(deliveryAddress.trim());
        if (coords != null) {
          delivery = LatLng(coords['lat']!, coords['lon']!);
        }
      }

      if (!mounted) return;
      setState(() {
        _shopPosition = shop;
        _deliveryPosition = delivery;
        _markers = _buildMarkers(
          shop: shop,
          delivery: delivery,
          shopSnippet: shopAddress,
        );
        _isLoading = false;
      });

      _fitMapCamera();
    } catch (e) {
      debugPrint('TrackingMap geocoding error: $e');
      if (!mounted) return;
      setState(() {
        _shopPosition = widget.showShopLocation ? _defaultCenter : null;
        _deliveryPosition = _defaultCenter;
        _markers = _buildMarkers(
          shop: widget.showShopLocation ? _defaultCenter : null,
          delivery: _defaultCenter,
          shopSnippet: shopAddress,
        );
        _isLoading = false;
      });
    }
  }

  void _fitMapCamera() {
    final controller = _controller;
    final shop = _shopPosition;
    final delivery = _deliveryPosition;
    if (delivery == null || controller == null) return;

    if (!widget.showShopLocation || shop == null) {
      try {
        controller.animateCamera(CameraUpdate.newLatLngZoom(delivery, 14));
      } catch (e, st) {
        NonUiErrorReporter.report('TrackingMap._fitMapCamera.delivery', e, st);
      }
      return;
    }

    try {
      final samePoint = shop.latitude == delivery.latitude &&
          shop.longitude == delivery.longitude;
      if (samePoint) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(shop, 14),
        );
        return;
      }
      final sw = LatLng(
        shop.latitude < delivery.latitude ? shop.latitude : delivery.latitude,
        shop.longitude < delivery.longitude ? shop.longitude : delivery.longitude,
      );
      final ne = LatLng(
        shop.latitude > delivery.latitude ? shop.latitude : delivery.latitude,
        shop.longitude > delivery.longitude ? shop.longitude : delivery.longitude,
      );
      final bounds = LatLngBounds(southwest: sw, northeast: ne);
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 24));
    } catch (e, st) {
      NonUiErrorReporter.report('TrackingMap._fitMapCamera', e, st);
      try {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(delivery, 14),
        );
      } catch (e2, st2) {
        NonUiErrorReporter.report('TrackingMap._fitMapCamera.fallback', e2, st2);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.of(context).size.height;
    final center = _deliveryPosition ?? _shopPosition ?? _defaultCenter;

    return SizedBox(
      height: widget.height ?? mediaHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: _deliveryPosition != null && _shopPosition != null
                    ? 10.0
                    : _defaultZoom,
              ),
              markers: _markers,
              onMapCreated: (controller) {
                _controller = controller;
                if (_deliveryPosition != null) {
                  _fitMapCamera();
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          if (_isLoading)
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('Updating location…', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LiveTrackingPlaceholderCard extends StatelessWidget {
  const LiveTrackingPlaceholderCard({
    super.key,
    required this.order,
  });

  final OrderTrackingModel order;

  @override
  Widget build(BuildContext context) {
    final accent = Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live tracking',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.grey.shade900,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.stageLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MockMapPanel(order: order),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      child: Icon(
                        order.supportsCourierDetails
                            ? Icons.person_rounded
                            : Icons.delivery_dining_rounded,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.courierName?.isNotEmpty == true
                                ? order.courierName!
                                : 'Courier will appear here',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.courierVehicle?.isNotEmpty == true
                                ? order.courierVehicle!
                                : 'Delivery updates and rider details will show here when available.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionPill(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Message',
                        accent: accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: [
              _DetailCard(
                icon: Icons.location_on_outlined,
                title: 'Drop-off',
                value: order.deliveryAddress,
              ),
              const SizedBox(height: 12),
              _DetailCard(
                icon: Icons.schedule_outlined,
                title: 'ETA',
                value: order.estimatedDeliveryTime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockMapPanel extends StatelessWidget {
  const _MockMapPanel({
    required this.order,
  });

  final OrderTrackingModel order;

  @override
  Widget build(BuildContext context) {
    final accent = Colors.green.shade700;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _MapPainter(accent: accent),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    order.liveTrackingNote ??
                        'Live courier updates will appear here when available.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.accent,
  });

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE4E8EA)
      ..strokeWidth = 0.8;

    for (double x = 20; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 20; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePaint = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.18,
        size.width * 0.52,
        size.height * 0.36,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.56,
        size.width * 0.78,
        size.height * 0.46,
      );
    canvas.drawPath(path, routePaint);

    _drawMarker(canvas, Offset(size.width * 0.22, size.height * 0.28), accent);
    _drawMarker(canvas, Offset(size.width * 0.78, size.height * 0.46), accent);
    _drawCourier(canvas, Offset(size.width * 0.52, size.height * 0.36), accent);
  }

  void _drawMarker(Canvas canvas, Offset center, Color accent) {
    final outer = Paint()..color = accent;
    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, 11, outer);
    canvas.drawCircle(center, 4, inner);
  }

  void _drawCourier(Canvas canvas, Offset center, Color accent) {
    final riderPaint = Paint()..color = accent;
    canvas.drawCircle(center.translate(0, -8), 7, riderPaint);
    final bikePaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center.translate(-12, 10), 8, bikePaint);
    canvas.drawCircle(center.translate(12, 10), 8, bikePaint);
    canvas.drawLine(center.translate(-8, 4), center.translate(6, 0), bikePaint);
    canvas.drawLine(center.translate(6, 0), center.translate(14, 8), bikePaint);
    canvas.drawLine(
        center.translate(-2, -2), center.translate(-10, 4), bikePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
