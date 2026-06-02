// pages/map_picker_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../config/api_config.dart';
import '../models/map_place_suggestion.dart';
import '../services/google_places_service.dart';
import '../widgets/animated_map_pin.dart';
import '../utils/app_error_utils.dart';

typedef LocationSelectedCallback = void Function(
    double lat, double lng, String? address);

/// Default map center (Accra) when coordinates are missing or invalid.
const LatLng _kAccraCenter = LatLng(5.6037, -0.1870);

class MapPickerPage extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final LocationSelectedCallback onLocationSelected;

  const MapPickerPage({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationSelected,
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

    print('🗺️ [MAP] MapPickerPage initialized');
    print(
        '   📍 Initial location: (${widget.initialLatitude}, ${widget.initialLongitude})');
    print(
        '   📍 [iOS DEBUG] Widget coordinates received: (${widget.initialLatitude}, ${widget.initialLongitude})');
    print(
        '   📍 [iOS DEBUG] Data types: ${widget.initialLatitude.runtimeType}, ${widget.initialLongitude.runtimeType}');
    print('   📍 [iOS DEBUG] _initialLocation created: $_initialLocation');
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

  Future<void> _getAddressFromCoordinates(double lat, double lng,
      {String? originalQuery}) async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingAddress = true;
        _selectedAddress = 'Getting address...';
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // If we have an originalQuery from Places API, ALWAYS prioritize it as the place name
        // The Places API name is more authoritative than reverse geocoded name
        String address;
        if (originalQuery != null && _isValidPlaceName(originalQuery)) {
          // Build address using originalQuery as place name and reverse geocoded street address
          List<String> addressParts = [];

          // Add street components from reverse geocoding
          if (place.subThoroughfare != null &&
              place.subThoroughfare!.isNotEmpty) {
            addressParts.add(place.subThoroughfare!);
          }
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
            addressParts.add(place.thoroughfare!);
          }

          // Use originalQuery (from Places API) as place name, then street address
          if (addressParts.isNotEmpty) {
            address = '$originalQuery, ${addressParts.join(' ')}';
          } else {
            // If no street address, use just the place name
            address = originalQuery;
          }
        } else {
          // No originalQuery, use reverse geocoded address
          address = _buildReadableAddress(place);
        }

        if (!mounted) return;

        if (address.isNotEmpty) {
          setState(() {
            _selectedAddress = address;
            _isLoadingAddress = false;
          });
          await _updateMarkers();
        } else {
          setState(() {
            _selectedAddress = 'Unknown location';
            _isLoadingAddress = false;
          });
          await _updateMarkers();
        }
      } else {
        if (!mounted) return;
        setState(() {
          _selectedAddress = originalQuery ?? 'Address not found';
          _isLoadingAddress = false;
        });
        await _updateMarkers();
      }
    } catch (e) {
      debugPrint('🗺️ [MAP] Error getting address: $e');
      if (!mounted) return;
      setState(() {
        _selectedAddress = originalQuery ?? 'Error loading address';
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
      debugPrint('🗺️ [MAP] ✅ Location set: (${resolved.lat}, ${resolved.lng})');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            key: _mapWidgetKey,
            onMapCreated: _onMapCreated,
            onTap: _onMapTapped,
            initialCameraPosition: CameraPosition(
              target: _initialLocation,
              zoom: 18.0, // Higher zoom for better accuracy
            ),
            markers: _markers,
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
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Updating map…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top App Bar with Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Top row with back button and title
                      Row(
                        children: [
                          // Back Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.grey.shade800,
                                size: 20,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Title
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '📍 Pick Your Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (!ApiConfig.hasGoogleMapsApiKey)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.amber.shade900,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Map search needs GOOGLE_MAPS_API_KEY. '
                                    'You can still tap the map or use current location.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber.shade900,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TypeAheadField<MapPlaceSuggestion>(
                                textFieldConfiguration: TextFieldConfiguration(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (value) {
                                    final trimmed = value.trim();
                                    if (trimmed.isNotEmpty) {
                                      _searchLocation(trimmed);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search for a location...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                suggestionsCallback: (pattern) async {
                                  return await _getSearchSuggestions(pattern);
                                },
                                itemBuilder: (context, suggestion) {
                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.green[600],
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      suggestion.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Tap to show on map',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  );
                                },
                                onSuggestionSelected: (suggestion) {
                                  _searchController.text =
                                      suggestion.description;
                                  _searchLocation(
                                    suggestion.description,
                                    placeId: suggestion.placeId,
                                    latitude: suggestion.latitude,
                                    longitude: suggestion.longitude,
                                  );
                                },
                                noItemsFoundBuilder: (context) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No locations found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                },
                                debounceDuration:
                                    const Duration(milliseconds: 300),
                                suggestionsBoxDecoration:
                                    SuggestionsBoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 12,
                                  shadowColor: Colors.black.withOpacity(0.15),
                                  constraints: const BoxConstraints(
                                    maxHeight: 280,
                                  ),
                                ),
                                animationDuration:
                                    const Duration(milliseconds: 200),
                                hideOnEmpty: false,
                                hideOnLoading: false,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[600],
                                  size: 18,
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

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle Bar
                      Container(
                        width: 32,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Compact Location Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isLoadingAddress
                                      ? 'Loading address...'
                                      : _selectedAddress,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Coordinates
                              Text(
                                '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Confirm Button (disabled while search/place update is in progress)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isUpdatingLocation
                              ? null
                              : () {
                                  print(
                                      '🗺️ [MAP] ===== CONFIRMING LOCATION =====');
                                  print(
                                      '🗺️ [MAP] Selected location: $_selectedLocation');
                                  print(
                                      '🗺️ [MAP] Latitude: ${_selectedLocation.latitude}');
                                  print(
                                      '🗺️ [MAP] Longitude: ${_selectedLocation.longitude}');
                                  print(
                                      '🗺️ [MAP] Calling onLocationSelected callback');
                                  print(
                                      '🗺️ [MAP] Selected address: $_selectedAddress');

                                  try {
                                    widget.onLocationSelected(
                                      _selectedLocation.latitude,
                                      _selectedLocation.longitude,
                                      _selectedAddress, // Pass the address along with coordinates
                                    );

                                    print(
                                        '🗺️ [MAP] Location confirmed and callback called');
                                  } catch (e) {
                                    print(
                                        '❌ [MAP] Error in onLocationSelected callback: $e');
                                    AppErrorUtils.showSnack(
                                        context, 'Error: $e');
                                  }

                                  // Pop after a brief delay to ensure callback completes
                                  Future.delayed(
                                      const Duration(milliseconds: 100), () {
                                    if (mounted) {
                                      Navigator.pop(context);
                                    }
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Compact Instructions
                      Text(
                        '💡 Search, tap the map, or use the location button',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Action Button for Current Location
          Positioned(
            bottom: 280,
            right: 20,
            child: FloatingActionButton(
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
                      if (mounted) {
                        AppErrorUtils.showSnack(
                          context,
                          'Location permission is required to use your position.',
                          isError: true,
                        );
                      }
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
                  if (mounted) {
                    AppErrorUtils.showSnack(
                      context,
                      'Could not get your location. Try again or pick on the map.',
                      isError: true,
                    );
                  }
                  await _animateMapTo(_initialLocation, zoom: 18.0);
                } finally {
                  if (mounted) setState(() => _isUpdatingLocation = false);
                }
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade600,
              elevation: 8,
              child: Icon(
                Icons.my_location,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
