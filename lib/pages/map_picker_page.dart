// pages/map_picker_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/google_places_service.dart';
import '../widgets/animated_map_pin.dart';
import '../utils/app_error_utils.dart';

typedef LocationSelectedCallback = void Function(
    double lat, double lng, String? address);

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
  late GoogleMapController _mapController;
  late LatLng _selectedLocation;
  late LatLng _initialLocation;
  Set<Marker> _markers = {};
  String _selectedAddress = 'Loading address...';
  bool _isLoadingAddress = true;

  /// True while searching/updating location (Places or Geocoding); disable Confirm until done.
  bool _isUpdatingLocation = false;

  // search box for finding places
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateMarkers() async {
    // make a custom marker icon that animates
    final customIcon = await CustomAnimatedMarker.createAnimatedMarker(
      text: '📍',
      backgroundColor: Colors.green,
      textColor: Colors.white,
      icon: Icons.location_on,
      size: 50.0,
    );

    _markers = {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedLocation,
        infoWindow: const InfoWindow(
          title: 'Selected Location',
          snippet: 'Use search or current location to select',
        ),
        draggable:
            false, // Disabled - users can only select via search or current location
        icon: customIcon,
      ),
    };
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
        } else {
          setState(() {
            _selectedAddress = 'Unknown location';
            _isLoadingAddress = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _selectedAddress = originalQuery ?? 'Address not found';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('🗺️ [MAP] Error getting address: $e');
      if (!mounted) return;
      setState(() {
        _selectedAddress = originalQuery ?? 'Error loading address';
        _isLoadingAddress = false;
      });
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

  // get search suggestions as they type using Google Places Autocomplete API
  Future<List<String>> _getSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      List<String> suggestions = [];
      Set<String> uniqueSuggestions = {}; // Prevent duplicates

      // Try Google Places Autocomplete API first (better for place names)
      try {
        print('🗺️ [MAP] Calling Google Places Autocomplete for "$query"');
        final autocompleteSuggestions =
            await _placesService.autocompleteDescriptions(query);
        for (final description in autocompleteSuggestions) {
          if (!uniqueSuggestions.contains(description)) {
            suggestions.add(description);
            uniqueSuggestions.add(description);
          }
        }
      } catch (e) {
        print('🗺️ [MAP] Places Autocomplete error: $e');
      }

      // Fallback: platform geocoder (avoids Geocoding REST API / REQUEST_DENIED)
      if (suggestions.length < 5) {
        final searchQueries = [
          '$query, Accra, Ghana',
          '$query, Ghana',
          query,
        ];

        for (final searchQuery in searchQueries) {
          if (suggestions.length >= 15) break;

          final result = await _platformGeocodeAddress(searchQuery);
          if (result == null) continue;

          var displayAddress = result.label;
          if (displayAddress.contains(',')) {
            final parts = displayAddress.split(',');
            if (parts.length >= 2) {
              displayAddress = '${parts[0].trim()}, ${parts[1].trim()}';
            }
          }

          if (displayAddress.isNotEmpty &&
              !uniqueSuggestions.contains(displayAddress)) {
            suggestions.add(displayAddress);
            uniqueSuggestions.add(displayAddress);
          }
        }
      }

      print('🗺️ [MAP] Total suggestions found: ${suggestions.length}');

      return suggestions.take(15).toList();
    } catch (e) {
      print('🗺️ [MAP] Error getting suggestions: $e');
      return [];
    }
  }

  // search for a place and move the map to it (using Google Geocoding API or Places API)
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    if (!mounted) return;
    setState(() => _isUpdatingLocation = true);

    print('🗺️ [MAP] Searching for location: "$query"');

    // First, try to get place_id from Places Autocomplete for exact location
    String? placeId;
    try {
      placeId = await _placesService.findPlaceIdForDescription(query);
      if (placeId != null) {
        print('🗺️ [MAP] Found place_id: $placeId for "$query"');
      }
    } catch (e) {
      print('🗺️ [MAP] Error getting place_id: $e');
    }

    // If we have place_id, use Places Details API for exact location
    if (placeId != null) {
      try {
        print('🗺️ [MAP] Calling Places Details API for $placeId');
        final result = await _placesService.fetchPlaceDetails(placeId);
        if (result != null) {
            final location = result['geometry']?['location'];
            if (location is Map) {
            final double lat = (location['lat'] as num).toDouble();
            final double lng = (location['lng'] as num).toDouble();
            final formattedAddress = result['formatted_address'] as String?;
            final placeName = result['name'] as String?;

            print('🗺️ [MAP] ✅ Exact location from Places API: ($lat, $lng)');
            print('🗺️ [MAP] Place name: $placeName');
            print('🗺️ [MAP] Formatted address: $formattedAddress');

            LatLng newLocation = LatLng(lat, lng);

            print('🗺️ [MAP] ===== SETTING NEW LOCATION =====');
            print('🗺️ [MAP] New location coordinates: ($lat, $lng)');
            print('🗺️ [MAP] Previous selected location: $_selectedLocation');

            // CRITICAL: Update the selected location FIRST and synchronously
            _selectedLocation = newLocation;

            // Then update state to trigger UI refresh
            setState(() {
              // Location already set above, just trigger rebuild
            });

            print(
                '🗺️ [MAP] ✅ _selectedLocation updated to: $_selectedLocation');

            // move the map to show the new location
            await _mapController.animateCamera(
              CameraUpdate.newLatLngZoom(newLocation, 18.0),
            );

            print('🗺️ [MAP] Camera moved to: $newLocation');

            await _updateMarkers();
            print('🗺️ [MAP] Markers updated at: $_selectedLocation');

            // get the address for the new location
            await _getAddressFromCoordinates(lat, lng,
                originalQuery: placeName ?? query.split(',').first.trim());

            print('🗺️ [MAP] ✅ Location selection complete');
            if (mounted) setState(() => _isUpdatingLocation = false);
            return; // Success, exit early
          }
        }
      } catch (e) {
        print('🗺️ [MAP] Places Details API error: $e');
        // Fall through to geocoding
      }
    }

    // Fallback: platform geocoder (avoids Geocoding REST API / REQUEST_DENIED)
    final searchQueries = [
      query,
      '$query, Ghana',
      if (query.contains(',')) query.split(',').first.trim(),
    ];

    for (final searchQuery in searchQueries) {
      final geocoded = await _platformGeocodeAddress(searchQuery);
      if (geocoded == null) {
        print('🗺️ [MAP] ⚠️ No platform geocode result for "$searchQuery"');
        continue;
      }

      final lat = geocoded.lat;
      final lng = geocoded.lng;
      print('🗺️ [MAP] ✅ Location found via platform geocoder: ($lat, $lng)');

      var placeName = geocoded.label;
      if (placeName.contains(',')) {
        placeName = placeName.split(',').first.trim();
      }
      if (_isValidPlaceName(query)) {
        placeName = query.split(',').first.trim();
      }

      final newLocation = LatLng(lat, lng);

      print('🗺️ [MAP] ===== SETTING NEW LOCATION =====');
      print('🗺️ [MAP] New location coordinates: ($lat, $lng)');
      print('🗺️ [MAP] Previous selected location: $_selectedLocation');

      _selectedLocation = newLocation;
      setState(() {});

      await _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(newLocation, 18.0),
      );

      await _updateMarkers();
      await _getAddressFromCoordinates(lat, lng, originalQuery: placeName);

      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
      print('🗺️ [MAP] ✅ Location selection complete');
      return;
    }

    // If we get here, all searches failed
    print('🗺️ [MAP] ❌ All search attempts failed for: "$query"');
    if (mounted) {
      setState(() => _isUpdatingLocation = false);
      AppErrorUtils.showSnack(
        context,
        'Location not found: $query',
        isError: true,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              print('🗺️ [MAP] GoogleMap created successfully');
              print('🗺️ [MAP] [iOS DEBUG] Map controller created');
              print(
                  '🗺️ [MAP] [iOS DEBUG] About to move camera to: $_initialLocation');

              // Move camera to initial position with higher zoom for accuracy
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(_initialLocation, 18.0),
              );

              print('🗺️ [MAP] [iOS DEBUG] Camera animation started');
            },
            initialCameraPosition: CameraPosition(
              target: _initialLocation,
              zoom: 18.0, // Higher zoom for better accuracy
            ),
            markers: _markers,
            // onTap disabled - users can only select location via search or current location button
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
                              child: TypeAheadField<String>(
                                textFieldConfiguration: TextFieldConfiguration(
                                  controller: _searchController,
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
                                      suggestion,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Tap to navigate',
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
                                  _searchController.text = suggestion;
                                  _searchLocation(suggestion);
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
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.1),
                                ),
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
                        '💡 Tap map or drag marker to select location',
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
                if (!mounted) return;

                try {
                  // Check location permissions first
                  LocationPermission permission =
                      await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                    if (permission == LocationPermission.denied) {
                      print('🗺️ [MAP] Location permission denied');
                      return;
                    }
                  }

                  if (!mounted) return;

                  // Get current device location with high accuracy
                  Position position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.best,
                    timeLimit: const Duration(seconds: 15),
                  );

                  if (!mounted) return;

                  LatLng currentLocation =
                      LatLng(position.latitude, position.longitude);

                  setState(() {
                    _selectedLocation = currentLocation;
                    _updateMarkers();
                  });

                  // Move camera to current location with high zoom
                  _mapController.animateCamera(
                    CameraUpdate.newLatLngZoom(currentLocation, 19.0),
                  );

                  // Get address for current location
                  _getAddressFromCoordinates(
                      position.latitude, position.longitude);

                  print(
                      '🗺️ [MAP] Current location: (${position.latitude}, ${position.longitude})');
                  print('🗺️ [MAP] Accuracy: ${position.accuracy} meters');
                  print('🗺️ [MAP] Altitude: ${position.altitude} meters');
                  print('🗺️ [MAP] Speed: ${position.speed} m/s');
                } catch (e) {
                  print('🗺️ [MAP] Error getting current location: $e');
                  // Fallback to initial location
                  _mapController.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialLocation, 18.0),
                  );
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
