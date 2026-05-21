// pages/store_map_page.dart

import 'package:flutter/material.dart';

import '../models/store_location_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/animated_map_pin.dart';
import '../services/location_service.dart';

class StoreMapPage extends StatefulWidget {
  final List<dynamic> stores;
  final String? selectedStoreId;

  const StoreMapPage({
    super.key,
    required this.stores,
    this.selectedStoreId,
  });

  @override
  State<StoreMapPage> createState() => _StoreMapPageState();
}

class _StoreMapPageState extends State<StoreMapPage> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  String? _selectedMarkerId;
  Position? _userLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedMarkerId = widget.selectedStoreId;
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();

      setState(() {
        _userLocation = position;
        _isLoading = false;
      });

      await _createMarkers();

      // Move camera to show all stores
      if (_markers.isNotEmpty) {
        _fitMarkersInView();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error getting user location: $e');
    }
  }

  Future<void> _createMarkers() async {
    final markers = <Marker>{};

    print('🗺️ Creating markers for ${widget.stores.length} stores');

    // if we dont have any stores, add some test ones
    List<dynamic> storesToProcess = widget.stores;
    if (storesToProcess.isEmpty) {
      print('🗺️ No stores available, adding test stores');
      storesToProcess = [
        {
          'id': 'test1',
          'description': 'Test Store Accra',
          'address': 'Accra, Ghana',
          'latitude': '5.6037',
          'longitude': '-0.1870',
        },
        {
          'id': 'test2',
          'description': 'Test Store Kumasi',
          'address': 'Kumasi, Ghana',
          'latitude': '6.6885',
          'longitude': '-1.6244',
        },
      ];
    }

    for (final store in storesToProcess) {
      final storeId = store['id']?.toString() ?? '';
      final storeName = store['description'] ?? 'Unknown Store';
      final storeAddress =
          (store['address'] ?? store['description'] ?? '').toString();

      print('🗺️ Processing store: $storeName');
      print('🗺️ Store data keys: ${store.keys.toList()}');
      print('🗺️ Latitude (latitude): ${store['latitude']}');
      print('🗺️ Longitude (longitude): ${store['longitude']}');
      print('🗺️ Latitude (lat): ${store['lat']}');
      print('🗺️ Longitude (lng): ${store['lng']}');

      // Get coordinates - check both field name variations
      double? lat, lng;

      // Try latitude/longitude first
      if (store['latitude'] != null && store['longitude'] != null) {
        final latValue = double.tryParse(store['latitude'].toString());
        final lngValue = double.tryParse(store['longitude'].toString());
        if (latValue != null &&
            lngValue != null &&
            latValue != 0.0 &&
            lngValue != 0.0) {
          lat = latValue;
          lng = lngValue;
          print('🗺️ Using API coordinates (latitude/longitude): $lat, $lng');
        }
      }

      // if that didnt work, try lat/lng
      if (lat == null || lng == null) {
        if (store['lat'] != null && store['lng'] != null) {
          final latValue = double.tryParse(store['lat'].toString());
          final lngValue = double.tryParse(store['lng'].toString());
          if (latValue != null &&
              lngValue != null &&
              latValue != 0.0 &&
              lngValue != 0.0) {
            lat = latValue;
            lng = lngValue;
            print('🗺️ Using API coordinates (lat/lng): $lat, $lng');
          }
        }
      }

      // if we still dont have coordinates, just guess based on the city
      if (lat == null || lng == null) {
        final coords = _getEstimatedCoordinates(store);
        lat = coords['lat']!;
        lng = coords['lng']!;
        print('🗺️ Using estimated coordinates: $lat, $lng');
      }

      final isSelected = storeId == _selectedMarkerId;

      // make a custom marker icon
      final customIcon = await CustomAnimatedMarker.createAnimatedMarker(
        text: '🏪',
        backgroundColor: isSelected ? Colors.blue : Colors.green,
        textColor: Colors.white,
        icon: Icons.store,
        size: 50.0,
      );

      markers.add(
        Marker(
          markerId: MarkerId(storeId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: storeName,
            snippet: storeAddress,
          ),
          icon: customIcon,
          onTap: () => _onMarkerTap(storeId),
        ),
      );
    }

    // add a marker for where the user is (if we know)
    if (_userLocation != null) {
      final userIcon = await CustomAnimatedMarker.createAnimatedMarker(
        text: '📍',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.person,
        size: 40.0,
      );

      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_userLocation!.latitude, _userLocation!.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
          icon: userIcon,
        ),
      );
    }

    print('🗺️ Created ${markers.length} markers');

    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTap(String markerId) {
    setState(() {
      _selectedMarkerId = markerId;
    });

    // remake markers with the new selection
    _createMarkers();

    // find which store they tapped and show its info
    final store = widget.stores.firstWhere(
      (store) => store['id']?.toString() == markerId,
      orElse: () => null,
    );

    if (store != null) {
      _showStoreInfo(store);
    }
  }

  void _showStoreInfo(dynamic store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // the drag handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // store name and address
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store,
                    color: Colors.green[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store['description'] ?? 'Unknown Store',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (store['address'] ?? store['description'] ?? '')
                                .toString()
                                .isNotEmpty
                            ? (store['address'] ?? store['description'])
                                .toString()
                            : 'No address available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              StoreLocationModel.hoursLabelFromMap(
                                Map<String, dynamic>.from(store as Map),
                              ),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // buttons to call or get directions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchMaps(
                      store['description'] ?? '',
                      store['address'] ?? '',
                    ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps(String storeName, String storeAddress) async {
    try {
      final query = Uri.encodeComponent('$storeName, $storeAddress');
      final url = 'https://www.google.com/maps/search/?api=1&query=$query';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the map')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _fitMarkersInView() {
    print('🗺️ _fitMarkersInView called with ${_markers.length} markers');
    if (_markers.isEmpty) {
      print('🗺️ No markers to fit in view');
      return;
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      print('🗺️ Marker at: $lat, $lng');

      minLat = minLat < lat ? minLat : lat;
      maxLat = maxLat > lat ? maxLat : lat;
      minLng = minLng < lng ? minLng : lng;
      maxLng = maxLng > lng ? maxLng : lng;
    }

    print('🗺️ Bounds: SW($minLat, $minLng) NE($maxLat, $maxLng)');

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
    print('🗺️ Camera animation started');
  }

  Map<String, double> _getEstimatedCoordinates(dynamic store) {
    // default to center of ghana if we dont know where it is
    double lat = 7.9465;
    double lng = -1.0232;

    final regionName = store['region_name']?.toString().toLowerCase() ?? '';
    final cityName = store['city_name']?.toString().toLowerCase() ?? '';
    final storeName = store['description']?.toString().toLowerCase() ?? '';

    print('🗺️ ESTIMATING COORDS for: $regionName, $cityName, $storeName');

    // More precise coordinates for major Ghanaian cities and regions
    if (regionName.contains('accra') || cityName.contains('accra')) {
      // accra region - use more specific coordinates
      if (storeName.contains('circle')) {
        lat = 5.5500;
        lng = -0.1833;
        print('🗺️ Using Circle Accra coordinates: $lat, $lng');
      } else if (storeName.contains('nester') || storeName.contains('square')) {
        lat = 5.6037;
        lng = -0.1870;
        print('🗺️ Using Nester Square coordinates: $lat, $lng');
      } else if (storeName.contains('volta') || storeName.contains('place')) {
        lat = 5.6037;
        lng = -0.1870;
        print('🗺️ Using Volta Place coordinates: $lat, $lng');
      } else {
        // General Accra coordinates
        lat = 5.6037;
        lng = -0.1870;
        print('🗺️ Using general Accra coordinates: $lat, $lng');
      }
    } else if (regionName.contains('kumasi') || cityName.contains('kumasi')) {
      lat = 6.6885;
      lng = -1.6244;
      print('🗺️ Using Kumasi coordinates: $lat, $lng');
    } else if (regionName.contains('tamale') || cityName.contains('tamale')) {
      lat = 9.4035;
      lng = -0.8423;
      print('🗺️ Using Tamale coordinates: $lat, $lng');
    } else if (regionName.contains('sekondi') ||
        cityName.contains('sekondi') ||
        regionName.contains('takoradi') ||
        cityName.contains('takoradi')) {
      lat = 4.9340;
      lng = -1.7300;
      print('🗺️ Using Sekondi-Takoradi coordinates: $lat, $lng');
    } else if (regionName.contains('sunyani') || cityName.contains('sunyani')) {
      lat = 7.3399;
      lng = -2.3268;
      print('🗺️ Using Sunyani coordinates: $lat, $lng');
    } else if (regionName.contains('ho') || cityName.contains('ho')) {
      lat = 6.6000;
      lng = 0.4700;
      print('🗺️ Using Ho coordinates: $lat, $lng');
    } else if (regionName.contains('koforidua') ||
        cityName.contains('koforidua')) {
      lat = 6.0833;
      lng = -0.2500;
      print('🗺️ Using Koforidua coordinates: $lat, $lng');
    } else if (regionName.contains('cape coast') ||
        cityName.contains('cape coast')) {
      lat = 5.1053;
      lng = -1.2466;
      print('🗺️ Using Cape Coast coordinates: $lat, $lng');
    } else if (regionName.contains('tema') || cityName.contains('tema')) {
      lat = 5.6795;
      lng = -0.0167;
      print('🗺️ Using Tema coordinates: $lat, $lng');
    } else if (regionName.contains('ashaiman') ||
        cityName.contains('ashaiman')) {
      lat = 5.6167;
      lng = -0.0667;
      print('🗺️ Using Ashaiman coordinates: $lat, $lng');
    } else if (regionName.contains('madina') || cityName.contains('madina')) {
      lat = 5.6833;
      lng = -0.1667;
      print('🗺️ Using Madina coordinates: $lat, $lng');
    } else if (regionName.contains('adenta') || cityName.contains('adenta')) {
      lat = 5.7000;
      lng = -0.1667;
      print('🗺️ Using Adenta coordinates: $lat, $lng');
    } else if (regionName.contains('spintex') || cityName.contains('spintex')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Spintex coordinates: $lat, $lng');
    } else if (regionName.contains('east legon') ||
        cityName.contains('east legon')) {
      lat = 5.6500;
      lng = -0.1833;
      print('🗺️ Using East Legon coordinates: $lat, $lng');
    } else if (regionName.contains('west legon') ||
        cityName.contains('west legon')) {
      lat = 5.6500;
      lng = -0.2000;
      print('🗺️ Using West Legon coordinates: $lat, $lng');
    } else if (regionName.contains('airport') || cityName.contains('airport')) {
      lat = 5.6053;
      lng = -0.1674;
      print('🗺️ Using Airport coordinates: $lat, $lng');
    } else if (regionName.contains('oshie') || cityName.contains('oshie')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Oshie coordinates: $lat, $lng');
    } else if (regionName.contains('dansoman') ||
        cityName.contains('dansoman')) {
      lat = 5.5500;
      lng = -0.2333;
      print('🗺️ Using Dansoman coordinates: $lat, $lng');
    } else if (regionName.contains('kanda') || cityName.contains('kanda')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Kanda coordinates: $lat, $lng');
    } else if (regionName.contains('nima') || cityName.contains('nima')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Nima coordinates: $lat, $lng');
    } else if (regionName.contains('mamprobi') ||
        cityName.contains('mamprobi')) {
      lat = 5.5500;
      lng = -0.2333;
      print('🗺️ Using Mamprobi coordinates: $lat, $lng');
    } else if (regionName.contains('korle bu') ||
        cityName.contains('korle bu')) {
      lat = 5.5500;
      lng = -0.2333;
      print('🗺️ Using Korle Bu coordinates: $lat, $lng');
    } else if (regionName.contains('jamestown') ||
        cityName.contains('jamestown')) {
      lat = 5.5500;
      lng = -0.2333;
      print('🗺️ Using Jamestown coordinates: $lat, $lng');
    } else if (regionName.contains('osu') || cityName.contains('osu')) {
      lat = 5.5500;
      lng = -0.1833;
      print('🗺️ Using Osu coordinates: $lat, $lng');
    } else if (regionName.contains('cantonments') ||
        cityName.contains('cantonments')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Cantonments coordinates: $lat, $lng');
    } else if (regionName.contains('labone') || cityName.contains('labone')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Labone coordinates: $lat, $lng');
    } else if (regionName.contains('ring road') ||
        cityName.contains('ring road')) {
      lat = 5.6167;
      lng = -0.1833;
      print('🗺️ Using Ring Road coordinates: $lat, $lng');
    } else if (regionName.contains('circle') || cityName.contains('circle')) {
      lat = 5.5500;
      lng = -0.1833;
      print('🗺️ Using Circle coordinates: $lat, $lng');
    } else {
      print('🗺️ Using default Ghana coordinates: $lat, $lng');
    }

    return {'lat': lat, 'lng': lng};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Locations'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_userLocation != null) {
                _mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_userLocation!.latitude, _userLocation!.longitude),
                    15.0,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              print('🗺️ Map controller created');
              // make sure all markers are visible on the map
              Future.delayed(const Duration(milliseconds: 1000), () {
                print('🗺️ Attempting to fit markers in view');
                _fitMarkersInView();
              });
            },
            initialCameraPosition: CameraPosition(
              target: _userLocation != null
                  ? LatLng(_userLocation!.latitude, _userLocation!.longitude)
                  : const LatLng(7.9465, -1.0232), // Ghana center
              zoom: 10.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            minMaxZoomPreference: const MinMaxZoomPreference(6.0, 20.0),
          ),

          // show how many stores there are
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.store,
                    color: Colors.green[700],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.stores.length} stores',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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
