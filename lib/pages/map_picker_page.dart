// pages/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class MapPickerPage extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final Function(double, double) onLocationSelected;

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
  late GoogleMapController _mapController;
  late LatLng _selectedLocation;
  late LatLng _initialLocation;
  Set<Marker> _markers = {};
  String _selectedAddress = 'Loading address...';
  bool _isLoadingAddress = true;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
    _selectedLocation = _initialLocation;
    _updateMarkers();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedLocation,
        infoWindow: const InfoWindow(
          title: 'Selected Location',
          snippet: 'Tap to confirm this location',
        ),
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onDragEnd: (newPosition) {
          setState(() {
            _selectedLocation = newPosition;
            _updateMarkers();
          });
          _getAddressFromCoordinates(
              newPosition.latitude, newPosition.longitude);
        },
      ),
    };
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      setState(() {
        _isLoadingAddress = true;
        _selectedAddress = 'Getting address...';
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';

        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          address += address.isNotEmpty
              ? ', ${place.subLocality}'
              : place.subLocality!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address +=
              address.isNotEmpty ? ', ${place.locality}' : place.locality!;
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          address += address.isNotEmpty
              ? ', ${place.administrativeArea}'
              : place.administrativeArea!;
        }

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
        setState(() {
          _selectedAddress = 'Address not found';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('🗺️ [MAP] Error getting address: $e');
      setState(() {
        _selectedAddress = 'Error loading address';
        _isLoadingAddress = false;
      });
    }
  }

  /// Get real-time search suggestions from map/geocoding
  Future<List<String>> _getSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      List<String> suggestions = [];

      // Real-time geocoding search for actual map locations
      try {
        // Search for the query in Ghana context
        List<Location> locations = await locationFromAddress('$query, Ghana');

        if (locations.isNotEmpty) {
          // Get detailed address for each location
          for (Location location in locations.take(5)) {
            try {
              List<Placemark> placemarks = await placemarkFromCoordinates(
                  location.latitude, location.longitude);

              if (placemarks.isNotEmpty) {
                Placemark place = placemarks[0];
                String address = '';

                // Build a readable address
                if (place.street != null && place.street!.isNotEmpty) {
                  address += place.street!;
                }
                if (place.subLocality != null &&
                    place.subLocality!.isNotEmpty) {
                  address += address.isNotEmpty
                      ? ', ${place.subLocality}'
                      : place.subLocality!;
                }
                if (place.locality != null && place.locality!.isNotEmpty) {
                  address += address.isNotEmpty
                      ? ', ${place.locality}'
                      : place.locality!;
                }
                if (place.administrativeArea != null &&
                    place.administrativeArea!.isNotEmpty) {
                  address += address.isNotEmpty
                      ? ', ${place.administrativeArea}'
                      : place.administrativeArea!;
                }

                if (address.isNotEmpty) {
                  suggestions.add(address);
                }
              }
            } catch (e) {
              // If detailed address fails, use coordinates
              suggestions.add(
                  '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}');
            }
          }
        }
      } catch (e) {
        print('🗺️ [MAP] Geocoding error: $e');
      }

      // If no real results, add the original query as a suggestion
      if (suggestions.isEmpty && query.isNotEmpty) {
        suggestions.add('$query, Ghana');
      }

      return suggestions.take(8).toList();
    } catch (e) {
      print('🗺️ [MAP] Error getting suggestions: $e');
      return [];
    }
  }

  /// Search for a location and move map to it
  Future<void> _searchLocation(String query) async {
    try {
      // Geocode the search query
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        Location location = locations[0];
        LatLng newLocation = LatLng(location.latitude, location.longitude);

        // Move map to the new location
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(newLocation, 18.0),
        );

        // Update selected location and markers
        setState(() {
          _selectedLocation = newLocation;
          _updateMarkers();
        });

        // Get address for the new location
        _getAddressFromCoordinates(location.latitude, location.longitude);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location found: $query'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Success - no return needed for void method
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location not found: $query'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // No return needed for void method
      }
    } catch (e) {
      print('🗺️ [MAP] Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching for location: $query'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // No return needed for void method
    }
  }

  /// Restrict map movement to Ghana boundaries
  void _restrictMapToGhana(LatLng target) {
    // Ghana boundaries (approximate)
    const double minLat = 4.5; // Southern boundary
    const double maxLat = 11.2; // Northern boundary
    const double minLng = -3.3; // Western boundary
    const double maxLng = 1.3; // Eastern boundary

    double restrictedLat = target.latitude;
    double restrictedLng = target.longitude;

    // Restrict latitude to Ghana boundaries
    if (target.latitude < minLat) {
      restrictedLat = minLat;
    } else if (target.latitude > maxLat) {
      restrictedLat = maxLat;
    }

    // Restrict longitude to Ghana boundaries
    if (target.longitude < minLng) {
      restrictedLng = minLng;
    } else if (target.longitude > maxLng) {
      restrictedLng = maxLng;
    }

    // If position was restricted, move camera back to valid area
    if (restrictedLat != target.latitude || restrictedLng != target.longitude) {
      print(
          '🗺️ [MAP] Position restricted to Ghana boundaries: ($restrictedLat, $restrictedLng)');
      _mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(restrictedLat, restrictedLng)),
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
            onTap: (LatLng position) {
              setState(() {
                _selectedLocation = position;
                _updateMarkers();
              });
              _getAddressFromCoordinates(position.latitude, position.longitude);
              print(
                  '🗺️ [MAP] Map tapped at: (${position.latitude}, ${position.longitude})');
            },
            onCameraMove: (CameraPosition position) {
              // Restrict map movement to Ghana boundaries
              _restrictMapToGhana(position.target);
            },
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

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onLocationSelected(
                              _selectedLocation.latitude,
                              _selectedLocation.longitude,
                            );
                            Navigator.pop(context);
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

                  // Get current device location with high accuracy
                  Position position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.best,
                    timeLimit: const Duration(seconds: 15),
                  );

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
