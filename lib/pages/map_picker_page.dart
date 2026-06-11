// pages/map_picker_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eclapp/widgets/safe_typeahead_host.dart';
import 'package:eclapp/widgets/typeahead_box_style.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import '../models/delivery_geofence.dart';
import '../models/map_place_suggestion.dart';
import '../services/delivery_service.dart';
import '../utils/app_theme_colors.dart';
import '../utils/point_in_polygon.dart';
import '../services/google_places_service.dart';
import '../widgets/animated_map_pin.dart';
import '../widgets/map/map_dark_style.dart';
import '../widgets/map/outside_delivery_area_dialog.dart';
import '../utils/app_error_utils.dart';
import 'package:google_fonts/google_fonts.dart';

typedef LocationSelectedCallback = void Function(
    double lat, double lng, String? address);

/// Default map center (Accra) when coordinates are missing or invalid.
const LatLng _kAccraCenter = LatLng(5.6037, -0.1870);

class MapPickerPage extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final LocationSelectedCallback onLocationSelected;

  /// Called when the picked point is outside the delivery geofence so the
  /// parent can switch to pickup without saving the delivery location.
  final VoidCallback? onOfferPickup;

  const MapPickerPage({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationSelected,
    this.onOfferPickup,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final GooglePlacesService _placesService = GooglePlacesService();
  late final Key _mapWidgetKey;
  GoogleMapController? _mapController;
  bool _mapReady = false;
  LatLng? _pendingCameraTarget;
  double _pendingCameraZoom = 18.0;
  late LatLng _selectedLocation;
  late LatLng _initialLocation;
  Set<Marker> _markers = {};
  String _selectedAddress = 'Loading address...';
  bool _isLoadingAddress = true;

  /// True while searching/updating location (Places or Geocoding); disable Confirm until done.
  bool _isUpdatingLocation = false;

  /// True while `/validate-geofence` is in flight.
  bool _isValidatingLocation = false;

  Set<Polygon> _deliveryPolygons = {};
  DeliveryGeofence? _deliveryGeofence;

  // search box for finding places
  final TextEditingController _searchController = TextEditingController();

  static bool _coordinatesLookValid(double lat, double lng) {
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    // Treat (0,0) as unset — common when backend has no coordinates yet.
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _mapWidgetKey = UniqueKey();
    final valid = _coordinatesLookValid(
      widget.initialLatitude,
      widget.initialLongitude,
    );
    _initialLocation = valid
        ? LatLng(widget.initialLatitude, widget.initialLongitude)
        : _kAccraCenter;
    _selectedLocation = _initialLocation;
    _initializeMarkers();
    _getAddressFromCoordinates(widget.initialLatitude, widget.initialLongitude);
    unawaited(_loadDeliveryGeofence());

    print('🗺️ [MAP] MapPickerPage initialized');
    print(
        '   📍 Initial location: (${widget.initialLatitude}, ${widget.initialLongitude})');
    print(
        '   📍 [iOS DEBUG] Widget coordinates received: (${widget.initialLatitude}, ${widget.initialLongitude})');
    print(
        '   📍 [iOS DEBUG] Data types: ${widget.initialLatitude.runtimeType}, ${widget.initialLongitude.runtimeType}');
    print('   📍 [iOS DEBUG] _initialLocation created: $_initialLocation');
  }

  Future<void> _loadDeliveryGeofence() async {
    try {
      final geofence = await DeliveryService.fetchDeliveryGeofence();
      if (!mounted || geofence == null || !geofence.hasPolygons) return;

      _deliveryGeofence = geofence;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final polygons = <Polygon>{};
      for (var i = 0; i < geofence.polygons.length; i++) {
        polygons.add(
          Polygon(
            polygonId: PolygonId('delivery_zone_$i'),
            points: geofence.polygons[i],
            fillColor: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            strokeColor: isDark ? AppColors.primaryLight : AppColors.primaryDark,
            strokeWidth: 2,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _deliveryPolygons = polygons);
    } catch (e) {
      debugPrint('🗺️ [MAP] delivery-geofence load failed: $e');
    }
  }

  Future<GeofenceValidationResult> _resolveGeofenceValidation() async {
    final validation = await DeliveryService.validateGeofence(
      lat: _selectedLocation.latitude,
      lng: _selectedLocation.longitude,
    );

    if (validation.checkedRemotely) {
      return validation;
    }

    if (_deliveryGeofence != null && _deliveryGeofence!.hasPolygons) {
      final inside = PointInPolygon.isInside(
        _selectedLocation,
        _deliveryGeofence!.polygons,
      );
      return GeofenceValidationResult(
        isValid: inside,
        message: inside ? null : DeliveryGeofenceCopy.outsideArea,
        checkedRemotely: false,
      );
    }

    return const GeofenceValidationResult(
      isValid: false,
      message: DeliveryGeofenceCopy.cannotVerify,
      checkedRemotely: false,
    );
  }

  Future<void> _showOutsideDeliveryAreaDialog(String message) async {
    final switchToPickup = await showOutsideDeliveryAreaDialog(
      context,
      message: message,
      offerPickup: widget.onOfferPickup != null,
    );

    if (!mounted || switchToPickup != true) return;

    widget.onOfferPickup!.call();
    Navigator.pop(context);
  }

  Future<void> _confirmLocation() async {
    if (_isUpdatingLocation || _isValidatingLocation) return;

    setState(() => _isValidatingLocation = true);
    try {
      final validation = await _resolveGeofenceValidation();

      if (!mounted) return;

      if (!validation.isValid) {
        final message = validation.message ?? DeliveryGeofenceCopy.outsideArea;
        if (widget.onOfferPickup != null) {
          await _showOutsideDeliveryAreaDialog(message);
        } else {
          AppErrorUtils.showSnack(context, message);
        }
        return;
      }

      widget.onLocationSelected(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
        _selectedAddress,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppErrorUtils.showSnack(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isValidatingLocation = false);
    }
  }

  Future<void> _initializeMarkers() async {
    await _updateMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    _mapReady = false;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _animateMapTo(LatLng location, {double zoom = 17.0}) async {
    if (!_mapReady || _mapController == null) {
      _pendingCameraTarget = location;
      _pendingCameraZoom = zoom;
      return;
    }
    _pendingCameraTarget = null;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(location, zoom),
    );
  }

  Future<void> _flushPendingCamera() async {
    final target = _pendingCameraTarget;
    if (target == null || _mapController == null) return;
    final zoom = _pendingCameraZoom;
    _pendingCameraTarget = null;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;
    if (Theme.of(context).brightness == Brightness.dark) {
      unawaited(controller.setMapStyle(kMapPickerDarkStyle));
    }
    if (_pendingCameraTarget != null) {
      unawaited(_flushPendingCamera());
    } else {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation, 18.0),
        ),
      );
    }
    if (_markers.isEmpty) {
      unawaited(_updateMarkers());
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);
    try {
      _selectedLocation = position;
      await _updateMarkers();
      await _animateMapTo(position, zoom: 18.0);
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  Future<void> _updateMarkers() async {
    BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueGreen,
    );
    try {
      markerIcon = await CustomAnimatedMarker.createAnimatedMarker(
        text: '📍',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.location_on,
        size: 50.0,
      );
    } catch (e) {
      print('🗺️ [MAP] Custom marker icon failed, using default: $e');
    }

    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation,
          infoWindow: InfoWindow(
            title: 'Selected location',
            snippet: _selectedAddress.length > 60
                ? '${_selectedAddress.substring(0, 60)}...'
                : _selectedAddress,
          ),
          draggable: false,
          icon: markerIcon,
          zIndexInt: 2,
        ),
      };
    });
  }

  bool _isPlatformGeocoderNetworkError(Object error) {
    final message = error.toString();
    return message.contains('IO_ERROR') ||
        message.contains('kCLErrorDomain') ||
        message.contains('Code=2');
  }

  String _coordinatesFallbackLabel(double lat, double lng) {
    return 'Dropped pin (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  Future<String?> _reverseGeocodePlatform(double lat, double lng) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isEmpty) return null;
        final built = _buildReadableAddress(placemarks.first);
        return built == 'Unknown location' ? null : built;
      } catch (e) {
        if (_isPlatformGeocoderNetworkError(e) && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  String _mergePlaceNameWithAddress(String placeName, String streetAddress) {
    if (streetAddress.isEmpty) return placeName;
    if (streetAddress.toLowerCase().contains(placeName.toLowerCase())) {
      return streetAddress;
    }
    return '$placeName, $streetAddress';
  }

  Future<String> _resolveAddressLabel(
    double lat,
    double lng, {
    String? originalQuery,
  }) async {
    String? platformAddress;
    try {
      platformAddress = await _reverseGeocodePlatform(lat, lng);
    } catch (e) {
      debugPrint('🗺️ [MAP] Platform reverse geocode failed: $e');
    }

    if (originalQuery != null && _isValidPlaceName(originalQuery)) {
      if (platformAddress != null && platformAddress.isNotEmpty) {
        return _mergePlaceNameWithAddress(originalQuery, platformAddress);
      }
      return originalQuery;
    }

    if (platformAddress != null && platformAddress.isNotEmpty) {
      return platformAddress;
    }

    try {
      final googleAddress =
          await _placesService.reverseGeocodeCoordinates(lat, lng);
      if (googleAddress != null && googleAddress.isNotEmpty) {
        debugPrint('🗺️ [MAP] Using Google reverse geocode fallback');
        return googleAddress;
      }
    } catch (e) {
      debugPrint('🗺️ [MAP] Google reverse geocode failed: $e');
    }

    return _coordinatesFallbackLabel(lat, lng);
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng,
      {String? originalQuery}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
      _selectedAddress = 'Getting address...';
    });

    try {
      final address = await _resolveAddressLabel(
        lat,
        lng,
        originalQuery: originalQuery,
      );

      if (!mounted) return;
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
      await _updateMarkers();
    } catch (e) {
      debugPrint('🗺️ [MAP] Error getting address: $e');
      if (!mounted) return;
      setState(() {
        _selectedAddress = originalQuery ?? _coordinatesFallbackLabel(lat, lng);
        _isLoadingAddress = false;
      });
      await _updateMarkers();
    }
  }

  /// Check if a name looks like a real place name (not a Plus Code or just numbers)
  bool _isValidPlaceName(String? name) {
    if (name == null || name.isEmpty) return false;

    final trimmed = name.trim();

    // Reject Plus Codes (e.g., "HRXF+F4X") - they have + and are short alphanumeric
    if (trimmed.contains('+') &&
        trimmed.length <= 15 &&
        RegExp(r'^[A-Z0-9]+\+[A-Z0-9]+$').hasMatch(trimmed)) {
      return false;
    }

    // Reject if it's just numbers (but allow numbers with letters like "3rd Street")
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return false;

    // Reject very short names (but allow 3+ characters)
    if (trimmed.length < 3) return false;

    // Must contain at least one letter to be a real place name
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) return false;

    return true;
  }

  /// Build a readable address from placemark, combining multiple components
  /// Returns a complete address string with place name, street number, and street name
  String _buildReadableAddress(Placemark place) {
    List<String> addressParts = [];
    String? placeName;

    // Get place name first if available and valid
    if (_isValidPlaceName(place.name)) {
      placeName = place.name;
    }

    // Add sub-thoroughfare (street number) if available
    if (place.subThoroughfare != null &&
        place.subThoroughfare!.isNotEmpty &&
        place.subThoroughfare != placeName) {
      addressParts.add(place.subThoroughfare!);
    }

    // Add thoroughfare (street name) if available
    if (place.thoroughfare != null &&
        place.thoroughfare!.isNotEmpty &&
        place.thoroughfare != placeName) {
      addressParts.add(place.thoroughfare!);
    }

    // Build the address: place name first, then street address
    if (placeName != null && addressParts.isNotEmpty) {
      String streetAddress = addressParts.join(' ');
      // Only add place name if it's not already in the street address
      if (!streetAddress.toLowerCase().contains(placeName.toLowerCase())) {
        return '$placeName, $streetAddress';
      }
      return '$placeName, $streetAddress';
    }

    // If we have street components but no place name, use street address
    if (addressParts.isNotEmpty) {
      return addressParts.join(' ');
    }

    // If we have place name but no street, use place name
    if (placeName != null) {
      return placeName;
    }

    // Fallback: Use street if available
    if (place.street != null && place.street!.isNotEmpty) {
      return place.street!;
    }

    // Fallback: Use sub-locality (neighborhood/area)
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      return place.subLocality!;
    }

    // Fallback: Use locality (city)
    if (place.locality != null && place.locality!.isNotEmpty) {
      return place.locality!;
    }

    // Fallback: Use administrative area (region)
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      return place.administrativeArea!;
    }

    // Fallback: Return unknown if nothing is available
    return 'Unknown location';
  }

  void _logGoogleMapsApiDenied(String apiName, Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    if (status != 'REQUEST_DENIED') return;
    print(
      '🗺️ [MAP] $apiName REQUEST_DENIED — enable the API in Google Cloud Console '
      'and ensure the key allows it (REST calls from the app often fail when the '
      'key is restricted to iOS/Android apps only). Using platform geocoding instead.',
    );
    final message = data['error_message']?.toString();
    if (message != null && message.isNotEmpty) {
      print('🗺️ [MAP] Google error_message: $message');
    }
  }

  /// Forward geocode via OS geocoder (no Geocoding REST API / API key required).
  Future<({double lat, double lng, String label})?> _platformGeocodeAddress(
    String address,
  ) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) return null;

      final loc = locations.first;
      var label = address.trim();
      try {
        final placemarks = await placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );
        if (placemarks.isNotEmpty) {
          final built = _buildReadableAddress(placemarks.first);
          if (built.isNotEmpty && built != 'Unknown location') {
            label = built;
          }
        }
      } catch (_) {}

      return (lat: loc.latitude, lng: loc.longitude, label: label);
    } catch (e) {
      print('🗺️ [MAP] Platform geocode failed for "$address": $e');
      return null;
    }
  }

  Future<List<MapPlaceSuggestion>> _getSearchSuggestions(String query) async {
    if (query.trim().length < 2) return [];

    if (!ApiConfig.hasGoogleMapsApiKey) {
      debugPrint(
        '🗺️ [MAP] No GOOGLE_MAPS_API_KEY — map search will be limited.',
      );
    }

    try {
      final suggestions = await _placesService.searchSuggestions(query);
      debugPrint(
        '🗺️ [MAP] searchSuggestions("$query") → ${suggestions.length} results',
      );
      return suggestions;
    } catch (e) {
      debugPrint('🗺️ [MAP] searchSuggestions error: $e');
      return [];
    }
  }

  Future<void> _applyResolvedLocation({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final newLocation = LatLng(lat, lng);
    _selectedLocation = newLocation;
    if (mounted) setState(() {});

    await _animateMapTo(newLocation, zoom: 17.0);
    await _updateMarkers();

    final nameHint = label.split(',').first.trim();
    await _getAddressFromCoordinates(
      lat,
      lng,
      originalQuery: _isValidPlaceName(nameHint) ? nameHint : null,
    );
  }

  Future<void> _searchLocation(
    String query, {
    String? placeId,
    double? latitude,
    double? longitude,
  }) async {
    if (query.trim().isEmpty) return;
    if (!mounted) return;
    setState(() => _isUpdatingLocation = true);

    debugPrint('🗺️ [MAP] Searching for location: "$query"');

    try {
      var resolved = await _placesService.resolveToCoordinates(
        query: query,
        placeId: placeId,
        latitude: latitude,
        longitude: longitude,
      );

      resolved ??= await _resolveViaPlatformGeocoder(query);

      if (resolved == null) {
        if (mounted) {
          AppErrorUtils.showSnack(
            context,
            ApiConfig.hasGoogleMapsApiKey
                ? 'Could not find "$query". Try adding the area or city name.'
                : 'Map search is not configured. Add GOOGLE_MAPS_API_KEY to .env.',
            isError: true,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      await _applyResolvedLocation(
        lat: resolved.lat,
        lng: resolved.lng,
        label: resolved.label,
      );
      debugPrint(
          '🗺️ [MAP] ✅ Location set: (${resolved.lat}, ${resolved.lng})');
    } catch (e) {
      debugPrint('🗺️ [MAP] _searchLocation error: $e');
      if (mounted) {
        AppErrorUtils.showSnack(
          context,
          'Could not load that location. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  Future<({double lat, double lng, String label})?> _resolveViaPlatformGeocoder(
    String query,
  ) async {
    final attempts = [
      if (!query.toLowerCase().contains('ghana')) '$query, Ghana',
      query,
    ];
    for (final attempt in attempts) {
      final geocoded = await _platformGeocodeAddress(attempt);
      if (geocoded == null) continue;
      return (lat: geocoded.lat, lng: geocoded.lng, label: geocoded.label);
    }
    return null;
  }

  BoxDecoration _glassCardDecoration(AppThemeColors theme) {
    return BoxDecoration(
      color: theme.isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: theme.isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.isDark ? 0.35 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Scaffold(
      backgroundColor: theme.pageBg,
      body: Stack(
        children: [
          GoogleMap(
            key: _mapWidgetKey,
            onMapCreated: _onMapCreated,
            onTap: _onMapTapped,
            initialCameraPosition: CameraPosition(
              target: _initialLocation,
              zoom: 18.0, // Higher zoom for better accuracy
            ),
            markers: _markers,
            polygons: _deliveryPolygons,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            compassEnabled: true,
            liteModeEnabled: false,
            mapType: MapType.normal,
            // Better location accuracy settings
            indoorViewEnabled: false,
            trafficEnabled: false,
            // Restrict zoom levels for Ghana
            minMaxZoomPreference: const MinMaxZoomPreference(6.0, 20.0),
          ),

          if (_isUpdatingLocation)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: _glassCardDecoration(theme),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Updating map…',
                          style: GoogleFonts.poppins(
                            color: theme.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 220.ms, curve: Curves.easeOut)
                      .scale(
                        begin: const Offset(0.94, 0.94),
                        duration: 220.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              ),
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Animate(
              effects: const [
                FadeEffect(
                  duration: Duration(milliseconds: 420),
                  curve: Curves.easeOut,
                ),
                SlideEffect(
                  duration: Duration(milliseconds: 420),
                  begin: Offset(0, -0.08),
                  end: Offset.zero,
                  curve: Curves.easeOutCubic,
                ),
              ],
              child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.isDark
                      ? [
                          const Color(0xFF0F172A).withValues(alpha: 0.96),
                          const Color(0xFF0F172A).withValues(alpha: 0.72),
                          Colors.transparent,
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.32),
                          Colors.transparent,
                        ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: _glassCardDecoration(theme),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                color: theme.ink,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: _glassCardDecoration(theme),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pin_drop_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pick your location',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: theme.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!ApiConfig.hasGoogleMapsApiKey)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.isDark
                                  ? const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.12)
                                  : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Map search needs GOOGLE_MAPS_API_KEY. '
                                    'You can still tap the map or use current location.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: theme.isDark
                                          ? const Color(0xFFFCD34D)
                                          : Colors.amber.shade900,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Container(
                        decoration: _glassCardDecoration(theme),
                        child: Row(
                          children: [
                            Expanded(
                              child: SafeTypeAheadHost<MapPlaceSuggestion>(
                                builder: (context, suggestionsController) {
                                  final boxStyle = TypeAheadBoxStyle(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    elevation: 12,
                                    shadowColor: theme.isDark
                                        ? const Color(0x66000000)
                                        : const Color(0x26000000),
                                    constraints: const BoxConstraints(
                                      maxHeight: 280,
                                    ),
                                  );

                                  return TypeAheadField<MapPlaceSuggestion>(
                                    controller: _searchController,
                                    suggestionsController:
                                        suggestionsController,
                                    offset: boxStyle.offset,
                                    constraints: boxStyle.constraints,
                                    decorationBuilder: (context, child) {
                                      return Material(
                                        color: theme.sheetBg,
                                        elevation: 12,
                                        shadowColor: theme.isDark
                                            ? Colors.black
                                            : const Color(0x26000000),
                                        borderRadius: BorderRadius.circular(12),
                                        child: child,
                                      );
                                    },
                                    animationDuration:
                                        const Duration(milliseconds: 200),
                                    builder: (context, controller, focusNode) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        onChanged: (_) => setState(() {}),
                                        onSubmitted: (value) {
                                          final trimmed = value.trim();
                                          if (trimmed.isNotEmpty) {
                                            _searchLocation(trimmed);
                                          }
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Search for a place…',
                                          hintStyle: GoogleFonts.poppins(
                                            color: theme.inputHint,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color: theme.muted,
                                            size: 20,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: theme.inputText,
                                        ),
                                      );
                                    },
                                    suggestionsCallback: (pattern) async {
                                      return _getSearchSuggestions(pattern);
                                    },
                                    itemBuilder: (context, suggestion) {
                                      return ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: theme.accentTint,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.location_on_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          suggestion.description,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: theme.ink,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'Show on map',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: theme.muted,
                                          ),
                                        ),
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      );
                                    },
                                    onSelected: (suggestion) {
                                      _searchController.text =
                                          suggestion.description;
                                      _searchLocation(
                                        suggestion.description,
                                        placeId: suggestion.placeId,
                                        latitude: suggestion.latitude,
                                        longitude: suggestion.longitude,
                                      );
                                    },
                                    emptyBuilder: (context) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'No locations found',
                                          style: GoogleFonts.poppins(
                                            color: theme.muted,
                                            fontSize: 14,
                                          ),
                                        ),
                                      );
                                    },
                                    debounceDuration:
                                        const Duration(milliseconds: 300),
                                    hideOnEmpty: false,
                                    hideOnLoading: false,
                                  );
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: theme.muted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
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
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Animate(
              effects: const [
                FadeEffect(
                  duration: Duration(milliseconds: 480),
                  delay: Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                ),
                SlideEffect(
                  duration: Duration(milliseconds: 480),
                  delay: Duration(milliseconds: 120),
                  begin: Offset(0, 0.18),
                  end: Offset.zero,
                  curve: Curves.easeOutCubic,
                ),
              ],
              child: Container(
              decoration: BoxDecoration(
                color: theme.sheetBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: theme.border),
                  left: BorderSide(color: theme.border),
                  right: BorderSide(color: theme.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.isDark ? 0.4 : 0.1,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.place_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.12),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _isLoadingAddress
                                    ? 'Loading address…'
                                    : _selectedAddress,
                                key: ValueKey<String>(
                                  _isLoadingAddress
                                      ? 'loading'
                                      : _selectedAddress,
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.ink,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed:
                              (_isUpdatingLocation || _isValidatingLocation)
                                  ? null
                                  : _confirmLocation,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.35),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Row(
                              key: ValueKey<bool>(_isValidatingLocation),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isValidatingLocation)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  _isValidatingLocation
                                      ? 'Checking…'
                                      : 'Confirm location',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
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
            ),
            ),
          ),

          Positioned(
            bottom: 150,
            right: 20,
            child: Animate(
              effects: const [
                FadeEffect(
                  duration: Duration(milliseconds: 400),
                  delay: Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                ),
                ScaleEffect(
                  duration: Duration(milliseconds: 400),
                  delay: Duration(milliseconds: 280),
                  begin: Offset(0.82, 0.82),
                  end: Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
              ],
              child: FloatingActionButton(
              heroTag: 'map_picker_my_location',
              onPressed: () async {
                if (!mounted || _isUpdatingLocation) return;
                setState(() => _isUpdatingLocation = true);

                try {
                  // Check location permissions first
                  LocationPermission permission =
                      await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                    if (permission == LocationPermission.denied) {
                      if (!context.mounted) return;
                      AppErrorUtils.showSnack(
                        context,
                        'Location permission is required to use your position.',
                        isError: true,
                      );
                      return;
                    }
                  }

                  if (!mounted) return;

                  // Get current device location with high accuracy
                  final position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.best,
                    timeLimit: const Duration(seconds: 15),
                  );

                  if (!mounted) return;

                  final currentLocation =
                      LatLng(position.latitude, position.longitude);

                  _selectedLocation = currentLocation;
                  await _updateMarkers();
                  await _animateMapTo(currentLocation, zoom: 18.0);
                  await _getAddressFromCoordinates(
                    position.latitude,
                    position.longitude,
                  );
                } catch (e) {
                  debugPrint('🗺️ [MAP] Error getting current location: $e');
                  if (!context.mounted) return;
                  AppErrorUtils.showSnack(
                    context,
                    'Could not get your location. Try again or pick on the map.',
                    isError: true,
                  );
                  await _animateMapTo(_initialLocation, zoom: 18.0);
                } finally {
                  if (mounted) setState(() => _isUpdatingLocation = false);
                }
              },
              backgroundColor: theme.sheetBg,
              foregroundColor: AppColors.primary,
              elevation: theme.isDark ? 6 : 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.border),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                size: 24,
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
