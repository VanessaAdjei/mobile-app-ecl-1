// pages/storelocation.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'app_back_button.dart';
import 'HomePage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../services/delivery_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store_location_model.dart';
import 'store_map_page.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  StoreSelectionPageState createState() => StoreSelectionPageState();
}

class StoreSelectionPageState extends State<StoreSelectionPage>
    with TickerProviderStateMixin {
  // data from the api
  List<dynamic> regions = [];
  List<dynamic> cities = [];
  List<dynamic> stores = [];
  List<dynamic> allStores = [];

  // what they picked
  dynamic selectedRegion;
  dynamic selectedCity;

  // sorting and location stuff
  String sortBy = 'distance'; // sort by distance by default
  bool isLocationAvailable = false;
  Position? userLocation;
  bool isLoadingLocation = false;

  // if they want to type in their location manually
  bool showManualLocationInput = false;
  final TextEditingController _locationController = TextEditingController();
  double? manualLatitude;
  double? manualLongitude;

  // are we loading stuff?
  bool isLoadingRegions = false;
  bool isLoadingCities = false;
  bool isLoadingStores = false;
  bool isLoadingAllStores = false;
  bool isLoading = false;

  // error messages
  String? regionsError;
  String? citiesError;
  String? storesError;
  String? allStoresError;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  // hide/show filters when scrolling
  final ScrollController _scrollController = ScrollController();
  bool _showFilters = true;
  double _lastScrollOffset = 0.0;

  /// Recent API responses for on-page debug viewer (newest first).
  final List<Map<String, dynamic>> _apiResponseLogs = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // listen for scrolling so we can hide/show filters
    _scrollController.addListener(_onScroll);

    // load the data when page starts
    _loadRegions();
    _loadAllStores();
    _initializeLocation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Handle scroll events to show/hide filters
  void _onScroll() {
    final currentOffset = _scrollController.offset;

    // Hide filters when scrolling down, show when scrolling up
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      // Scrolling down and past threshold - hide filters
      if (_showFilters) {
        setState(() {
          _showFilters = false;
        });
      }
    } else if (currentOffset < _lastScrollOffset && currentOffset < 100) {
      // scrolling up near the top, show filters
      if (!_showFilters) {
        setState(() {
          _showFilters = true;
        });
      }
    }

    _lastScrollOffset = currentOffset;
  }

  // set up location stuff
  Future<void> _initializeLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      final locationService = LocationService();
      isLocationAvailable = await locationService.isLocationAvailable();

      if (isLocationAvailable) {
        userLocation = await locationService.getCurrentLocation();
        debugPrint(
            '📍 Location initialized: ${userLocation?.latitude}, ${userLocation?.longitude}');

        // Check if location is within Ghana (rough bounds)
        if (userLocation != null) {
          final isInGhana = _isLocationInGhana(
              userLocation!.latitude, userLocation!.longitude);
          if (!isInGhana) {
            debugPrint(
                '⚠️ Location is outside Ghana, setting default Accra location');
            _setDefaultGhanaLocation();
          } else {
            debugPrint('✅ Location is within Ghana');
          }
        }

        // test that distance calculation works
        _testDistanceCalculation();

        // Refresh stores to apply distance sorting now that location is available
        if (allStores.isNotEmpty) {
          setState(() {
            // update the ui to show stores sorted by distance
          });
        }
      } else {
        debugPrint('❌ Location services not available');
        // if we cant get their location, just use a default ghana location
        _setDefaultGhanaLocation();
      }
    } catch (e) {
      debugPrint('❌ Error initializing location: $e');
      // if something went wrong, use default ghana location
      _setDefaultGhanaLocation();
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  // Sort stores based on selected criteria
  List<dynamic> _sortStores(List<dynamic> stores) {
    if (stores.isEmpty) return stores;

    debugPrint('📍 Sorting by: $sortBy');

    switch (sortBy) {
      case 'distance':
        if (userLocation != null) {
          debugPrint('📍 Sorting by distance (user location available)');
          return _sortByDistance(stores);
        } else {
          debugPrint(
              '📍 Cannot sort by distance - no location available, falling back to name');
          return _sortByName(stores);
        }
      case 'name':
      default:
        debugPrint('📍 Sorting by name');
        return _sortByName(stores);
    }
  }

  // sort stores by how far they are from the user
  List<dynamic> _sortByDistance(List<dynamic> stores) {
    final locationService = LocationService();

    debugPrint('📍 DISTANCE SORTING DEBUG ===');
    debugPrint(
        'User Location: ${userLocation?.latitude}, ${userLocation?.longitude}');
    debugPrint('User Location Accuracy: ${userLocation?.accuracy} meters');
    debugPrint('Number of stores to sort: ${stores.length}');

    if (userLocation == null) {
      debugPrint('❌ ERROR: User location is null! Cannot sort by distance.');
      return stores; // Return unsorted if no location
    }

    // only use stores that have valid coordinates
    final storesWithCoords = stores.where((store) {
      final lat = store['lat'];
      final lon = store['lng'];

      if (lat == null || lon == null) {
        debugPrint('⚠️ Store ${store['description']}: Missing coordinates');
        return false;
      }

      final latValue = double.tryParse(lat.toString());
      final lonValue = double.tryParse(lon.toString());

      if (latValue == null ||
          lonValue == null ||
          latValue == 0.0 ||
          lonValue == 0.0) {
        debugPrint(
            '⚠️ Store ${store['description']}: Invalid coordinates ($lat, $lon)');
        return false;
      }

      debugPrint(
          '✅ Store ${store['description']}: Valid coordinates ($latValue, $lonValue)');
      return true;
    }).toList();

    if (storesWithCoords.isEmpty) {
      debugPrint(
          '❌ No stores with valid coordinates found, falling back to name sorting');
      return _sortByName(stores);
    }

    debugPrint(
        '📍 Sorting ${storesWithCoords.length} stores with valid coordinates');

    return List<dynamic>.from(storesWithCoords)
      ..sort((a, b) {
        // get the coordinates from the api (we already checked theyre valid)
        final aLat = double.parse(a['lat'].toString());
        final aLon = double.parse(a['lng'].toString());
        final bLat = double.parse(b['lat'].toString());
        final bLon = double.parse(b['lng'].toString());

        debugPrint(
            'Store A (${a['description']}): API coords = ($aLat, $aLon)');
        debugPrint(
            'Store B (${b['description']}): API coords = ($bLat, $bLon)');

        // Calculate distances
        final aDistance = locationService.calculateDistance(
          userLocation!.latitude,
          userLocation!.longitude,
          aLat,
          aLon,
        );
        final bDistance = locationService.calculateDistance(
          userLocation!.latitude,
          userLocation!.longitude,
          bLat,
          bLon,
        );

        debugPrint(
            'Store A distance: ${locationService.formatDistance(aDistance)}');
        debugPrint(
            'Store B distance: ${locationService.formatDistance(bDistance)}');

        // add the distance to the store data so we can show it
        a['distance'] = aDistance;
        b['distance'] = bDistance;

        return aDistance.compareTo(bDistance);
      });

    // Debug: Show final sorted order
    debugPrint('📍 FINAL SORTED ORDER ===');
    for (int i = 0; i < storesWithCoords.length; i++) {
      final store = storesWithCoords[i];
      final distance = store['distance'] ?? 'N/A';
      debugPrint(
          '${i + 1}. ${store['description']} - ${locationService.formatDistance(distance)}');
    }
    debugPrint('========================');

    return storesWithCoords;
  }

  // Check if location is within Ghana bounds
  bool _isLocationInGhana(double lat, double lon) {
    // Ghana rough bounds: 4.5°N to 11.2°N, 3.3°W to 1.2°E
    return lat >= 4.5 && lat <= 11.2 && lon >= -3.3 && lon <= 1.2;
  }

  // use accra as the default location
  void _setDefaultGhanaLocation() {
    setState(() {
      userLocation = Position(
        latitude: 5.6037, // Accra coordinates
        longitude: -0.1870,
        timestamp: DateTime.now(),
        accuracy: 1000.0, // Lower accuracy since it's estimated
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      isLocationAvailable = true;
      manualLatitude = 5.6037;
      manualLongitude = -0.1870;
      _locationController.text = 'Accra (Default)';
    });
    debugPrint('📍 Default Ghana location set: Accra (5.6037, -0.1870)');

    // reload stores so we can sort by distance using default location
    if (allStores.isNotEmpty) {
      setState(() {
        // update ui to show stores sorted by distance
      });
    }
  }

  // Test distance calculation with known coordinates
  void _testDistanceCalculation() {
    final locationService = LocationService();

    // Test with Accra coordinates (5.6037, -0.1870)
    final accraLat = 5.6037;
    final accraLon = -0.1870;

    // test distances from a few different places
    final testLocations = [
      {'name': 'Circle Accra', 'lat': 5.5500, 'lon': -0.1833},
      {'name': 'Kumasi', 'lat': 6.6885, 'lon': -1.6244},
      {'name': 'Tema', 'lat': 5.6795, 'lon': -0.0167},
    ];

    debugPrint('🧪 TESTING DISTANCE CALCULATIONS ===');
    for (final location in testLocations) {
      final distance = locationService.calculateDistance(accraLat, accraLon,
          location['lat'] as double, location['lon'] as double);
      debugPrint(
          '${location['name']}: ${locationService.formatDistance(distance)}');
    }
    debugPrint('====================================');
  }

  // Get estimated coordinates based on region and city
  Map<String, double> _getEstimatedCoordinates(dynamic store) {
    // Default coordinates for Ghana (center of the country)
    double lat = 7.9465;
    double lon = -1.0232;

    final regionName = store['region_name']?.toString().toLowerCase() ?? '';
    final cityName = store['city_name']?.toString().toLowerCase() ?? '';
    final storeName = store['description']?.toString().toLowerCase() ?? '';

    debugPrint('📍 ESTIMATING COORDS for: $regionName, $cityName, $storeName');

    // More precise coordinates for major Ghanaian cities and regions
    if (regionName.contains('accra') || cityName.contains('accra')) {
      // accra region - use more specific coordinates
      if (storeName.contains('circle')) {
        lat = 5.5500;
        lon = -0.1833;
        debugPrint('📍 Using Circle Accra coordinates: $lat, $lon');
      } else if (storeName.contains('nester') || storeName.contains('square')) {
        lat = 5.6037;
        lon = -0.1870;
        debugPrint('📍 Using Nester Square coordinates: $lat, $lon');
      } else if (storeName.contains('volta') || storeName.contains('place')) {
        lat = 5.6037;
        lon = -0.1870;
        debugPrint('📍 Using Volta Place coordinates: $lat, $lon');
      } else {
        // General Accra coordinates
        lat = 5.6037;
        lon = -0.1870;
        debugPrint('📍 Using general Accra coordinates: $lat, $lon');
      }
    } else if (regionName.contains('kumasi') || cityName.contains('kumasi')) {
      lat = 6.6885;
      lon = -1.6244;
      debugPrint('📍 Using Kumasi coordinates: $lat, $lon');
    } else if (regionName.contains('tamale') || cityName.contains('tamale')) {
      lat = 9.4035;
      lon = -0.8423;
      debugPrint('📍 Using Tamale coordinates: $lat, $lon');
    } else if (regionName.contains('sekondi') ||
        cityName.contains('sekondi') ||
        regionName.contains('takoradi') ||
        cityName.contains('takoradi')) {
      lat = 4.9340;
      lon = -1.7300;
      debugPrint('📍 Using Sekondi-Takoradi coordinates: $lat, $lon');
    } else if (regionName.contains('sunyani') || cityName.contains('sunyani')) {
      lat = 7.3399;
      lon = -2.3268;
      debugPrint('📍 Using Sunyani coordinates: $lat, $lon');
    } else if (regionName.contains('ho') || cityName.contains('ho')) {
      lat = 6.6000;
      lon = 0.4700;
      debugPrint('📍 Using Ho coordinates: $lat, $lon');
    } else if (regionName.contains('koforidua') ||
        cityName.contains('koforidua')) {
      lat = 6.0833;
      lon = -0.2500;
      debugPrint('📍 Using Koforidua coordinates: $lat, $lon');
    } else if (regionName.contains('cape coast') ||
        cityName.contains('cape coast')) {
      lat = 5.1053;
      lon = -1.2466;
      debugPrint('📍 Using Cape Coast coordinates: $lat, $lon');
    } else if (regionName.contains('tema') || cityName.contains('tema')) {
      // Tema region - more specific coordinates
      lat = 5.6795;
      lon = -0.0167;
      debugPrint('📍 Using Tema coordinates: $lat, $lon');
    } else if (regionName.contains('ashaiman') ||
        cityName.contains('ashaiman')) {
      lat = 5.6167;
      lon = -0.0667;
      debugPrint('📍 Using Ashaiman coordinates: $lat, $lon');
    } else if (regionName.contains('madina') || cityName.contains('madina')) {
      lat = 5.6833;
      lon = -0.1667;
      debugPrint('📍 Using Madina coordinates: $lat, $lon');
    } else if (regionName.contains('adenta') || cityName.contains('adenta')) {
      lat = 5.7000;
      lon = -0.1667;
      debugPrint('📍 Using Adenta coordinates: $lat, $lon');
    } else if (regionName.contains('spintex') || cityName.contains('spintex')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Spintex coordinates: $lat, $lon');
    } else if (regionName.contains('east legon') ||
        cityName.contains('east legon')) {
      lat = 5.6500;
      lon = -0.1833;
      debugPrint('📍 Using East Legon coordinates: $lat, $lon');
    } else if (regionName.contains('west legon') ||
        cityName.contains('west legon')) {
      lat = 5.6500;
      lon = -0.2000;
      debugPrint('📍 Using West Legon coordinates: $lat, $lon');
    } else if (regionName.contains('airport') || cityName.contains('airport')) {
      lat = 5.6053;
      lon = -0.1674;
      debugPrint('📍 Using Airport coordinates: $lat, $lon');
    } else if (regionName.contains('oshie') || cityName.contains('oshie')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Oshie coordinates: $lat, $lon');
    } else if (regionName.contains('dansoman') ||
        cityName.contains('dansoman')) {
      lat = 5.5500;
      lon = -0.2333;
      debugPrint('📍 Using Dansoman coordinates: $lat, $lon');
    } else if (regionName.contains('kanda') || cityName.contains('kanda')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Kanda coordinates: $lat, $lon');
    } else if (regionName.contains('nima') || cityName.contains('nima')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Nima coordinates: $lat, $lon');
    } else if (regionName.contains('mamprobi') ||
        cityName.contains('mamprobi')) {
      lat = 5.5500;
      lon = -0.2333;
      debugPrint('📍 Using Mamprobi coordinates: $lat, $lon');
    } else if (regionName.contains('korle bu') ||
        cityName.contains('korle bu')) {
      lat = 5.5500;
      lon = -0.2333;
      debugPrint('📍 Using Korle Bu coordinates: $lat, $lon');
    } else if (regionName.contains('jamestown') ||
        cityName.contains('jamestown')) {
      lat = 5.5500;
      lon = -0.2333;
      debugPrint('📍 Using Jamestown coordinates: $lat, $lon');
    } else if (regionName.contains('osu') || cityName.contains('osu')) {
      lat = 5.5500;
      lon = -0.1833;
      debugPrint('📍 Using Osu coordinates: $lat, $lon');
    } else if (regionName.contains('cantonments') ||
        cityName.contains('cantonments')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Cantonments coordinates: $lat, $lon');
    } else if (regionName.contains('labone') || cityName.contains('labone')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Labone coordinates: $lat, $lon');
    } else if (regionName.contains('ring road') ||
        cityName.contains('ring road')) {
      lat = 5.6167;
      lon = -0.1833;
      debugPrint('📍 Using Ring Road coordinates: $lat, $lon');
    } else if (regionName.contains('circle') || cityName.contains('circle')) {
      lat = 5.5500;
      lon = -0.1833;
      debugPrint('📍 Using Circle coordinates: $lat, $lon');
    } else {
      debugPrint('📍 Using default Ghana coordinates: $lat, $lon');
    }

    return {'lat': lat, 'lon': lon};
  }

  // Sort stores by name
  List<dynamic> _sortByName(List<dynamic> stores) {
    debugPrint('📍 NAME SORTING DEBUG ===');
    debugPrint('Number of stores to sort: ${stores.length}');

    final sortedStores = List<dynamic>.from(stores)
      ..sort((a, b) {
        final aName = (a['description'] ?? '').toString().toLowerCase();
        final bName = (b['description'] ?? '').toString().toLowerCase();

        debugPrint('Comparing: "$aName" vs "$bName"');
        return aName.compareTo(bName);
      });

    // Debug: Show final sorted order
    debugPrint('📍 FINAL NAME SORTED ORDER ===');
    for (int i = 0; i < sortedStores.length; i++) {
      final store = sortedStores[i];
      debugPrint('${i + 1}. ${store['description']}');
    }
    debugPrint('=============================');

    return sortedStores;
  }

  void _recordStoreApiResponse(String endpoint, dynamic result) {
    String body;
    try {
      body = const JsonEncoder.withIndent('  ').convert(result);
    } catch (_) {
      body = result.toString();
    }
    final success = result is Map && result['success'] == true;
    debugPrint('════════════════════════════════════════');
    debugPrint('📡 STORE LOCATOR API: $endpoint');
    debugPrint(body);
    debugPrint('════════════════════════════════════════');
    if (!mounted) return;
    setState(() {
      _apiResponseLogs.insert(0, {
        'endpoint': endpoint,
        'body': body,
        'time': DateTime.now(),
        'success': success,
      });
      if (_apiResponseLogs.length > 25) {
        _apiResponseLogs.removeRange(25, _apiResponseLogs.length);
      }
    });
  }

  void _showApiResponsesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.75;
        return SafeArea(
          child: SizedBox(
            height: maxH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'API responses',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _apiResponseLogs.isEmpty
                      ? Center(
                          child: Text(
                            'No API calls yet.\nPull to refresh or change filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _apiResponseLogs.length,
                          itemBuilder: (context, index) {
                            final log = _apiResponseLogs[index];
                            final time = log['time'] as DateTime;
                            final ok = log['success'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                initiallyExpanded: index == 0,
                                leading: Icon(
                                  ok ? Icons.check_circle : Icons.error,
                                  color: ok
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red,
                                  size: 22,
                                ),
                                title: Text(
                                  log['endpoint'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${time.hour.toString().padLeft(2, '0')}:'
                                  '${time.minute.toString().padLeft(2, '0')}:'
                                  '${time.second.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.grey.shade100,
                                    child: SelectableText(
                                      log['body'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Load regions from API
  Future<void> _loadRegions() async {
    debugPrint('=== STORE LOCATION: Loading regions ===');
    setState(() {
      isLoadingRegions = true;
      regionsError = null;
    });

    try {
      debugPrint('Calling DeliveryService.getRegions()...');
      final result = await DeliveryService.getRegions();
      _recordStoreApiResponse('GET /regions', result);

      if (result['success']) {
        final regionsData = result['data'] ?? [];
        debugPrint('Regions data received: ${regionsData.length} regions');
        debugPrint('Regions: $regionsData');

        // Filter to only show Greater Accra, Ashanti, and Western regions
        final allowedRegionNames = [
          'greater accra',
          'ashanti',
          'western',
          'accra', // Also allow "Accra" as it might be named differently
        ];

        final filteredRegions = regionsData.where((region) {
          final regionName =
              (region['description'] ?? '').toString().toLowerCase().trim();
          final isAllowed =
              allowedRegionNames.any((allowed) => regionName.contains(allowed));

          if (!isAllowed) {
            debugPrint(
                '❌ Region filtered out: "$regionName" (original: "${region['description']}")');
          } else {
            debugPrint(
                '✅ Region allowed: "$regionName" (original: "${region['description']}")');
          }

          return isAllowed;
        }).toList();

        debugPrint('📋 Total regions from API: ${regionsData.length}');
        debugPrint('📋 Filtered regions count: ${filteredRegions.length}');
        debugPrint(
            '📋 Filtered region names: ${filteredRegions.map((r) => r['description']).toList()}');

        setState(() {
          regions = _dedupeLocationOptions(filteredRegions);
          isLoadingRegions = false;
        });
        debugPrint(
            'Regions loaded successfully: ${regions.length} regions (filtered from ${regionsData.length})');
      } else {
        debugPrint('Regions API failed: ${result['message']}');
        setState(() {
          regionsError = result['message'] ?? 'Failed to load regions';
          isLoadingRegions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading regions: $e');
      _recordStoreApiResponse('GET /regions', {
        'success': false,
        'message': e.toString(),
      });
      setState(() {
        regionsError = 'Network error: ${e.toString()}';
        isLoadingRegions = false;
      });
    }
  }

  // Load cities for selected region
  Future<void> _loadCities(dynamic region) async {
    if (region == null || region['id'] == null) {
      setState(() {
        cities = [];
        selectedCity = null;
      });
      return;
    }

    setState(() {
      isLoadingCities = true;
      citiesError = null;
      selectedCity = null;
    });

    try {
      final regionId = int.tryParse(region['id'].toString()) ?? 0;
      final result = await DeliveryService.getCitiesByRegion(regionId);
      _recordStoreApiResponse('GET /regions/$regionId/cities', result);

      if (result['success']) {
        setState(() {
          cities = result['data'] ?? [];
          isLoadingCities = false;
        });
      } else {
        setState(() {
          citiesError = result['message'] ?? 'Failed to load cities';
          isLoadingCities = false;
        });
      }
    } catch (e) {
      _recordStoreApiResponse('GET /regions/{id}/cities', {
        'success': false,
        'message': e.toString(),
      });
      setState(() {
        citiesError = 'Network error: ${e.toString()}';
        isLoadingCities = false;
      });
    }
  }

  // Load stores for selected city
  Future<void> _loadStores(dynamic city) async {
    if (city == null || city['id'] == null) {
      setState(() {
        stores = [];
      });
      return;
    }

    setState(() {
      isLoadingStores = true;
      storesError = null;
    });

    try {
      final cityId = int.tryParse(city['id'].toString()) ?? 0;
      final result = await DeliveryService.getStoresByCity(cityId);
      _recordStoreApiResponse('GET /cities/$cityId/stores', result);

      if (result['success']) {
        final rawList = result['data'] as List? ?? [];
        final normalized = rawList
            .whereType<Map>()
            .map((s) => DeliveryService.normalizeStoreMap(
                  Map<String, dynamic>.from(s),
                ))
            .toList();
        setState(() {
          stores = normalized;
          isLoadingStores = false;
        });
      } else {
        setState(() {
          storesError = result['message'] ?? 'Failed to load stores';
          isLoadingStores = false;
        });
      }
    } catch (e) {
      _recordStoreApiResponse('GET /cities/{id}/stores', {
        'success': false,
        'message': e.toString(),
      });
      setState(() {
        storesError = 'Network error: ${e.toString()}';
        isLoadingStores = false;
      });
    }
  }

  // Load ALL stores with parallel processing for speed
  Future<void> _loadAllStores() async {
    debugPrint('=== STORE LOCATION: Loading ALL stores ===');
    setState(() {
      isLoadingAllStores = true;
      allStoresError = null;
    });

    try {
      // Get all regions
      final regionsResult = await DeliveryService.getRegions();
      _recordStoreApiResponse('GET /regions (all stores)', regionsResult);
      if (!regionsResult['success']) {
        setState(() {
          allStoresError = regionsResult['message'] ?? 'Failed to load regions';
          isLoadingAllStores = false;
        });
        return;
      }

      final regionsData = regionsResult['data'] ?? [];

      // Filter to only show Greater Accra, Ashanti, and Western regions
      final allowedRegionNames = [
        'greater accra',
        'ashanti',
        'western',
        'accra', // Also allow "Accra" as it might be named differently
      ];

      final filteredRegions = regionsData.where((region) {
        final regionName =
            (region['description'] ?? '').toString().toLowerCase().trim();
        final isAllowed =
            allowedRegionNames.any((allowed) => regionName.contains(allowed));

        if (!isAllowed) {
          debugPrint(
              '❌ Region filtered out in _loadAllStores: "$regionName" (original: "${region['description']}")');
        }

        return isAllowed;
      }).toList();

      debugPrint(
          '🗺️ Filtered regions: ${filteredRegions.length} out of ${regionsData.length} total');
      for (var region in filteredRegions) {
        debugPrint('  ✅ Allowed region: ${region['description']}');
      }

      List<dynamic> allStoresList = [];

      // Load all cities for filtered regions in parallel
      List<Future<Map<String, dynamic>>> cityFutures = [];
      for (var region in filteredRegions) {
        final regionId = int.tryParse(region['id'].toString()) ?? 0;
        cityFutures.add(DeliveryService.getCitiesByRegion(regionId));
      }

      // Wait for all city requests to complete
      final cityResults = await Future.wait(cityFutures);

      // Load all stores for all cities in parallel
      List<Future<Map<String, dynamic>>> storeFutures = [];
      Map<int, Map<String, String>> cityInfo = {};

      for (int i = 0; i < cityResults.length; i++) {
        if (cityResults[i]['success']) {
          final citiesData = cityResults[i]['data'] ?? [];
          final region = filteredRegions[i];

          for (var city in citiesData) {
            final cityId = int.tryParse(city['id'].toString()) ?? 0;
            cityInfo[cityId] = {
              'region_name': region['description']?.toString() ?? '',
              'city_name': city['description']?.toString() ?? '',
            };
            storeFutures.add(DeliveryService.getStoresByCity(cityId));
          }
        }
      }

      // Wait for all store requests to complete
      final storeResults = await Future.wait(storeFutures);
      var totalStoresFetched = 0;
      for (final r in storeResults) {
        if (r['success'] == true && r['data'] is List) {
          totalStoresFetched += (r['data'] as List).length;
        }
      }
      _recordStoreApiResponse(
        'GET /cities/{id}/stores (batch ×${storeResults.length})',
        {
          'success': storeResults.every((r) => r['success'] == true),
          'requests': storeResults.length,
          'total_stores': totalStoresFetched,
          'results': storeResults.map((r) {
            final data = r['data'];
            return {
              'success': r['success'],
              'data_count': data is List ? data.length : 0,
              'message': r['message'],
              if (data is List && data.isNotEmpty) 'sample': data.first,
            };
          }).toList(),
        },
      );

      // Process all store results
      for (var storeResult in storeResults) {
        if (storeResult['success']) {
          final storesData = storeResult['data'] ?? [];
          for (var store in storesData) {
            final raw = Map<String, dynamic>.from(store as Map);
            final cityId = int.tryParse(raw['city_id'].toString()) ?? 0;
            var model = StoreLocationModel.fromApiJson(raw);
            if (cityInfo.containsKey(cityId)) {
              model = model.copyWith(
                regionName: cityInfo[cityId]!['region_name'],
                cityName: cityInfo[cityId]!['city_name'],
              );
            }
            final normalized = model.toMap();

            debugPrint('🔍 STORE DATA STRUCTURE ===');
            debugPrint('Store: ${normalized['description']}');
            debugPrint(
                'Hours: ${normalized['opening_time']} – ${normalized['closing_time']}');
            debugPrint('==========================');

            allStoresList.add(normalized);
          }
        }
      }

      setState(() {
        allStores = allStoresList;
        isLoadingAllStores = false;
      });
    } catch (e) {
      debugPrint('Error loading all stores: $e');
      _recordStoreApiResponse('load all stores', {
        'success': false,
        'message': e.toString(),
      });
      setState(() {
        allStoresError = 'Network error: ${e.toString()}';
        isLoadingAllStores = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeaderSection(),
              // Search and filter section below header - conditionally shown
              if (_showFilters) ...[
                Container(
                  margin: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: _buildSearchAndFilterCard(),
                ),
              ],
              Expanded(
                child: _buildStoreList(),
              ),
            ],
          ),
          // Floating action button to show filters when hidden
          if (!_showFilters)
            Positioned(
              bottom: 80, // Increased from 20 to avoid bottom navigation bar
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showFilters = true;
                  });
                  // Scroll to top to show filters
                  _scrollController.animateTo(
                    0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor: const Color(0xFF2E7D32),
                child: Icon(Icons.filter_list, color: Colors.white),
                mini: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding * 0.4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B5E20),
            const Color(0xFF2E7D32),
            const Color(0xFF43A047),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppBackButton(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shop Locator',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Locate the nearest Ernest Chemists store',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // API responses (debug)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      tooltip: 'API responses',
                      icon: Badge(
                        isLabelVisible: _apiResponseLogs.isNotEmpty,
                        label: Text(
                          '${_apiResponseLogs.length}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        child: const Icon(
                          Icons.data_object,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      onPressed: _showApiResponsesSheet,
                    ),
                  ),
                  // Map view button
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.map,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        // Use allStores if available, otherwise use filtered stores
                        final storesToShow = allStores.isNotEmpty
                            ? allStores
                            : _getFilteredAllStores();
                        print(
                            '🗺️ Opening map with ${storesToShow.length} stores');

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoreMapPage(
                              stores: storesToShow,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2E7D32)),
              SizedBox(width: 6),
              Text(
                'Filter Outlets',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildLocationEntityDropdown(
                    label: 'Region',
                    value: selectedRegion,
                    options: regions
                        .map((r) => Map<String, dynamic>.from(r as Map))
                        .toList(),
                    isLoading: isLoadingRegions,
                    error: regionsError,
                    onChanged: (Map<String, dynamic>? picked) {
                      setState(() {
                        selectedRegion = picked;
                        selectedCity = null;
                        cities = [];
                      });
                      if (picked != null) {
                        _loadCitiesForFiltering(picked);
                      }
                    },
                    onRetry: _loadRegions,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildLocationEntityDropdown(
                    label: 'City',
                    value: selectedCity,
                    options: cities
                        .map((c) => Map<String, dynamic>.from(c as Map))
                        .toList(),
                    isLoading: isLoadingCities,
                    error: citiesError,
                    enabled: selectedRegion != null,
                                       onChanged: (Map<String, dynamic>? picked) {
                      setState(() {
                        selectedCity = picked;
                      });
                    },
                    onRetry: () => _loadCitiesForFiltering(selectedRegion),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Region/city picker using stable [Map] values (avoids duplicate-label crashes).
  Widget _buildLocationEntityDropdown({
    required String label,
    required Map<String, dynamic>? value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<Map<String, dynamic>?> onChanged,
    bool isLoading = false,
    String? error,
    VoidCallback? onRetry,
    bool enabled = true,
    String emptyHint = 'No options available',
  }) {
    Map<String, dynamic>? effectiveValue;
    if (value != null) {
      final id = value['id']?.toString();
      final match = options.where((o) => o['id']?.toString() == id);
      if (match.isNotEmpty) {
        effectiveValue = match.first;
      }
    }

    final items = options
        .map(
          (o) => DropdownMenuItem<Map<String, dynamic>>(
            value: o,
            child: Text(
              o['description']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        )
        .toList();

    final canTap = enabled && !isLoading && items.isNotEmpty;

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: canTap ? effectiveValue : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade600, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : error != null
                ? IconButton(
                    icon: Icon(Icons.refresh,
                        color: Colors.red.shade400, size: 20),
                    onPressed: onRetry,
                  )
                : Icon(Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600, size: 20),
      ),
      hint: Text(
        isLoading
            ? 'Loading...'
            : (!enabled || items.isEmpty ? emptyHint : label),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: (!isLoading && (items.isEmpty || !enabled)) ? 11 : 13,
          color: Colors.grey.shade600,
        ),
      ),
      isExpanded: true,
      items: items,
      onChanged: canTap ? onChanged : null,
    );
  }

  Widget _buildStoreList() {
    debugPrint('📍 _buildStoreList called - sortBy: $sortBy');

    // Show loading state for all stores
    if (isLoadingAllStores) {
      return _buildLoadingSkeleton();
    }

    // Show error state for all stores
    if (allStoresError != null) {
      return _buildErrorState(allStoresError!, _loadAllStores);
    }

    // Filter all stores based on search query
    final filteredStores = _getFilteredAllStores();

    if (filteredStores.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController, // Add scroll controller
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredStores.length,
            itemBuilder: (context, index) {
              final store = filteredStores[index];
              return _buildStoreCard(store, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 13,
                          color: Colors.white,
                        ),
                        SizedBox(height: 5),
                        Container(
                          width: 160,
                          height: 10,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 10,
                color: Colors.white,
              ),
              SizedBox(height: 5),
              Container(
                width: 120,
                height: 10,
                color: Colors.white,
              ),
              SizedBox(height: 6),
              Container(
                width: double.infinity,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Error loading stores',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_mall_directory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No stores found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            selectedCity != null
                ? 'No stores available in ${selectedCity['name']}'
                : 'Please select a region and city to find stores',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                selectedRegion = null;
                selectedCity = null;

                stores = [];
              });
            },
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Clear Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _storeHoursLabel(dynamic store) {
    if (store is Map<String, dynamic>) {
      return StoreLocationModel.hoursLabelFromMap(store);
    }
    if (store is Map) {
      return StoreLocationModel.hoursLabelFromMap(
        Map<String, dynamic>.from(store),
      );
    }
    return 'Hours not listed';
  }

  Widget _buildStoreCard(dynamic store, int index) {
    final storeName = store['description'] ?? 'Unknown Store';
    final storeAddress =
        (store['address'] ?? store['description'] ?? '').toString();
    final storeHours = _storeHoursLabel(store);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _launchMaps(storeName, storeAddress),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF43A047),
                          const Color(0xFF2E7D32),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade200,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 1),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 12, color: Colors.grey.shade600),
                            SizedBox(width: 3),
                            if (store['region_name'] != null &&
                                store['city_name'] != null)
                              Expanded(
                                child: Text(
                                  '${store['city_name']}, ${store['region_name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            // Show distance if available
                            if (store['distance'] != null &&
                                sortBy == 'distance')
                              Container(
                                margin: EdgeInsets.only(left: 6),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFC8E6C9), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.straighten_rounded,
                                      size: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      _formatDistance(store['distance']),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (storeAddress.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: 15, top: 2),
                            child: Text(
                              storeAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: const Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 5),

              // Store Hours
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 12, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Text(
                    storeHours,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _launchMaps(storeName, storeAddress),
                  icon: Icon(Icons.directions_rounded,
                      size: 14, color: Colors.green.shade600),
                  label: Text(
                    'Get Directions',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9),
                    foregroundColor: const Color(0xFF2E7D32),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          BorderSide(color: const Color(0xFF2E7D32), width: 1),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Check if store is currently open (8:00 AM - 8:00 PM)
  bool _isStoreOpen() {
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);

    // Store hours: 8:00 AM - 8:00 PM
    final openTime = TimeOfDay(hour: 8, minute: 0);
    final closeTime = TimeOfDay(hour: 20, minute: 0); // 8:00 PM

    // Check if current time is between open and close time
    if (currentTime.hour > openTime.hour ||
        (currentTime.hour == openTime.hour &&
            currentTime.minute >= openTime.minute)) {
      if (currentTime.hour < closeTime.hour ||
          (currentTime.hour == closeTime.hour &&
              currentTime.minute < closeTime.minute)) {
        return true;
      }
    }
    return false;
  }

  // Format distance for display
  String _formatDistance(dynamic distance) {
    if (distance == null) return 'N/A';

    final distanceValue =
        distance is double ? distance : double.tryParse(distance.toString());
    if (distanceValue == null) return 'N/A';

    if (distanceValue < 1.0) {
      return '${(distanceValue * 1000).round()}m';
    } else if (distanceValue < 10.0) {
      return '${distanceValue.toStringAsFixed(1)}km';
    } else {
      return '${distanceValue.round()}km';
    }
  }

  // Get stores with valid coordinates for distance sorting
  List<dynamic> _getStoresWithValidCoords() {
    return allStores.where((store) {
      final lat = store['lat'];
      final lon = store['lng'];

      if (lat == null || lon == null) return false;

      final latValue = double.tryParse(lat.toString());
      final lonValue = double.tryParse(lon.toString());

      return latValue != null &&
          lonValue != null &&
          latValue != 0.0 &&
          lonValue != 0.0;
    }).toList();
  }

  Widget _buildCityCard(dynamic city) {
    final cityName = city['description'] ?? 'Unknown City';
    final isSelected = selectedCity != null && selectedCity['id'] == city['id'];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        color: isSelected ? Colors.green.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          leading: Icon(
            Icons.location_on,
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade600,
          ),
          title: Text(
            cityName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.green.shade800 : Colors.grey.shade800,
            ),
          ),
          subtitle: Text(
            'Tap to view stores',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: Colors.green.shade600)
              : Icon(Icons.arrow_forward_ios,
                  color: Colors.grey.shade400, size: 16),
          onTap: () {
            setState(() {
              selectedCity = city;
            });
            _loadStores(city);
          },
        ),
      ),
    );
  }

  // Load cities for filtering dropdown
  Future<void> _loadCitiesForFiltering(dynamic region) async {
    if (region == null || region['id'] == null) {
      setState(() {
        cities = [];
        selectedCity = null;
      });
      return;
    }

    setState(() {
      isLoadingCities = true;
      citiesError = null;
      selectedCity = null;
    });

    try {
      final regionId = int.tryParse(region['id'].toString()) ?? 0;
      final result = await DeliveryService.getCitiesByRegion(regionId);
      _recordStoreApiResponse(
        'GET /regions/$regionId/cities (filter)',
        result,
      );

      if (result['success']) {
        setState(() {
          cities = _dedupeLocationOptions(result['data'] ?? []);
          isLoadingCities = false;
        });
        debugPrint(
            'Cities loaded for filter: ${cities.map((c) => c['description']).toList()}');
      } else {
        setState(() {
          cities = [];
          citiesError = result['message'] ?? 'Failed to load cities';
          isLoadingCities = false;
        });
      }
    } catch (e) {
      _recordStoreApiResponse('GET /regions/{id}/cities (filter)', {
        'success': false,
        'message': e.toString(),
      });
      setState(() {
        cities = [];
        citiesError = 'Network error: ${e.toString()}';
        isLoadingCities = false;
      });
    }
  }

  /// Unique region/city rows for dropdowns (by id; skips empty labels).
  List<Map<String, dynamic>> _dedupeLocationOptions(List<dynamic> rows) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final label = (map['description'] ?? map['name'] ?? '').toString().trim();
      if (label.isEmpty) continue;
      final id = map['id']?.toString() ?? label;
      if (!seen.add(id)) continue;
      map['description'] = label;
      out.add(map);
    }
    return out;
  }

  List<dynamic> _getFilteredAllStores() {
    debugPrint('📍 _getFilteredAllStores called - sortBy: $sortBy');

    // Allowed regions: Greater Accra, Ashanti, and Western
    final allowedRegionNames = [
      'greater accra',
      'ashanti',
      'western',
      'accra', // Also allow "Accra" as it might be named differently
    ];

    final filteredStores = allStores.where((store) {
      // First, filter by allowed regions only
      final storeRegion =
          (store['region_name']?.toString() ?? '').toLowerCase();
      final isAllowedRegion =
          allowedRegionNames.any((allowed) => storeRegion.contains(allowed));

      if (!isAllowedRegion) {
        return false; // Skip stores not in allowed regions
      }

      // Filter by region if selected
      if (selectedRegion != null) {
        final selectedRegionName =
            selectedRegion['description']?.toString() ?? '';
        if (storeRegion != selectedRegionName.toLowerCase()) {
          return false;
        }
      }

      // Filter by city if selected
      if (selectedCity != null) {
        final storeCity =
            (store['city_name']?.toString() ?? '').toLowerCase().trim();
        final selectedCityName =
            (selectedCity['description']?.toString() ?? '').toLowerCase().trim();
        if (storeCity != selectedCityName) {
          return false;
        }
      }

      return true;
    }).toList();

    debugPrint('📍 Filtered stores count: ${filteredStores.length}');

    // Apply sorting
    final sortedStores = _sortStores(filteredStores);
    debugPrint('📍 Returning sorted stores count: ${sortedStores.length}');
    return sortedStores;
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
}
