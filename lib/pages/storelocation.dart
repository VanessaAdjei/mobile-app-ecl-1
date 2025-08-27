// pages/storelocation.dart
import 'package:flutter/material.dart';
import 'app_back_button.dart';
import 'HomePage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/delivery_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  StoreSelectionPageState createState() => StoreSelectionPageState();
}

class StoreSelectionPageState extends State<StoreSelectionPage>
    with TickerProviderStateMixin {
  // API Data
  List<dynamic> regions = [];
  List<dynamic> cities = [];
  List<dynamic> stores = [];
  List<dynamic> allStores = [];

  // Selected values
  dynamic selectedRegion;
  dynamic selectedCity;

  // Sorting and location
  String sortBy = 'distance'; // Default to distance sorting
  bool isLocationAvailable = false;
  Position? userLocation;
  bool isLoadingLocation = false;

  // Manual location input
  bool showManualLocationInput = false;
  final TextEditingController _locationController = TextEditingController();
  double? manualLatitude;
  double? manualLongitude;

  // Loading states
  bool isLoadingRegions = false;
  bool isLoadingCities = false;
  bool isLoadingStores = false;
  bool isLoadingAllStores = false;
  bool isLoading = false;

  // Error states
  String? regionsError;
  String? citiesError;
  String? storesError;
  String? allStoresError;

  late AnimationController _fadeController;
  late AnimationController _slideController;

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

    // Load initial data
    _loadRegions();
    _loadAllStores();
    _initializeLocation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Initialize location services
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

        // Test distance calculations
        _testDistanceCalculation();

        // Refresh stores to apply distance sorting now that location is available
        if (allStores.isNotEmpty) {
          setState(() {
            // Trigger rebuild to show stores sorted by distance
          });
        }
      } else {
        debugPrint('❌ Location services not available');
        // Set default Ghana location if location services not available
        _setDefaultGhanaLocation();
      }
    } catch (e) {
      debugPrint('❌ Error initializing location: $e');
      // Set default Ghana location on error
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

  // Sort stores by distance from user location
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

    // Filter stores with valid coordinates from API
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
        // Extract coordinates directly from API response (we know they're valid from filtering)
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

        // Add distance to store data for display
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

  // Set default Ghana location (Accra)
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

    // Refresh stores to apply distance sorting with default location
    if (allStores.isNotEmpty) {
      setState(() {
        // Trigger rebuild to show stores sorted by distance
      });
    }
  }

  // Test distance calculation with known coordinates
  void _testDistanceCalculation() {
    final locationService = LocationService();

    // Test with Accra coordinates (5.6037, -0.1870)
    final accraLat = 5.6037;
    final accraLon = -0.1870;

    // Test distances from different locations
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
      // Accra region - more specific coordinates based on store names
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
      debugPrint('Regions API result: $result');

      if (result['success']) {
        final regionsData = result['data'] ?? [];
        debugPrint('Regions data received: ${regionsData.length} regions');
        debugPrint('Regions: $regionsData');

        setState(() {
          regions = regionsData;
          isLoadingRegions = false;
        });
        debugPrint('Regions loaded successfully: ${regions.length} regions');
      } else {
        debugPrint('Regions API failed: ${result['message']}');
        setState(() {
          regionsError = result['message'] ?? 'Failed to load regions';
          isLoadingRegions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading regions: $e');
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

      if (result['success']) {
        setState(() {
          stores = result['data'] ?? [];
          isLoadingStores = false;
        });
      } else {
        setState(() {
          storesError = result['message'] ?? 'Failed to load stores';
          isLoadingStores = false;
        });
      }
    } catch (e) {
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
      if (!regionsResult['success']) {
        setState(() {
          allStoresError = regionsResult['message'] ?? 'Failed to load regions';
          isLoadingAllStores = false;
        });
        return;
      }

      final regionsData = regionsResult['data'] ?? [];
      List<dynamic> allStoresList = [];

      // Load all cities for all regions in parallel
      List<Future<Map<String, dynamic>>> cityFutures = [];
      for (var region in regionsData) {
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
          final region = regionsData[i];

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

      // Process all store results
      for (var storeResult in storeResults) {
        if (storeResult['success']) {
          final storesData = storeResult['data'] ?? [];
          for (var store in storesData) {
            final cityId = int.tryParse(store['city_id'].toString()) ?? 0;
            if (cityInfo.containsKey(cityId)) {
              store['region_name'] = cityInfo[cityId]!['region_name'];
              store['city_name'] = cityInfo[cityId]!['city_name'];
            }

            // Debug: Log store data structure
            debugPrint('🔍 STORE DATA STRUCTURE ===');
            debugPrint('Store: ${store['description']}');
            debugPrint('Keys: ${store.keys.toList()}');
            debugPrint('Latitude: ${store['latitude']}');
            debugPrint('Longitude: ${store['longitude']}');
            debugPrint('Address: ${store['address']}');
            debugPrint('Region: ${store['region_name']}');
            debugPrint('City: ${store['city_name']}');
            debugPrint('==========================');

            allStoresList.add(store);
          }
        }
      }

      setState(() {
        allStores = allStoresList;
        isLoadingAllStores = false;
      });
    } catch (e) {
      debugPrint('Error loading all stores: $e');
      setState(() {
        allStoresError = 'Network error: ${e.toString()}';
        isLoadingAllStores = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeaderSection(),
              // Search and filter section below header
              Container(
                margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSearchAndFilterCard(),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildSortingOptions(),
              ),
              Expanded(
                child: _buildStoreList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Animate(
      effects: [
        FadeEffect(duration: 400.ms),
        SlideEffect(duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
      ],
      child: Container(
        padding: EdgeInsets.only(top: topPadding * 0.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade600,
              Colors.green.shade700,
              Colors.green.shade800,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                            'Find a Store',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Locate the nearest Ernest Chemists store',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
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
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Region Dropdown
          Expanded(
            flex: 1,
            child: _buildCompactDropdown(
              value: selectedRegion,
              hint: 'Region',
              items: regions
                  .map<String>((region) => region['description'] ?? '')
                  .toList(),
              isLoading: isLoadingRegions,
              error: regionsError,
              onChanged: (String? newValue) {
                if (newValue == null || regions.isEmpty) return;

                final selectedRegionData = regions.firstWhere(
                  (region) => region['description'] == newValue,
                  orElse: () => null,
                );
                setState(() {
                  selectedRegion = selectedRegionData;
                  selectedCity = null;
                });
                if (selectedRegionData != null) {
                  _loadCitiesForFiltering(selectedRegionData);
                }
              },
              onRetry: _loadRegions,
            ),
          ),
          SizedBox(width: 4),
          // City Dropdown
          Expanded(
            flex: 1,
            child: _buildCompactDropdown(
              value: selectedCity,
              hint: 'City',
              items: cities
                  .map<String>((city) => city['description'] ?? '')
                  .toList(),
              isLoading: isLoadingCities,
              error: citiesError,
              onChanged: (String? newValue) {
                if (newValue == null || cities.isEmpty) return;

                final selectedCityData = cities.firstWhere(
                  (city) => city['description'] == newValue,
                  orElse: () => null,
                );
                setState(() {
                  selectedCity = selectedCityData;
                });
              },
              onRetry: () => _loadCitiesForFiltering(selectedRegion),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingOptions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sort, color: Colors.green.shade600, size: 16),
              SizedBox(width: 6),
              Text(
                'Sort by:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Name', 'name', Icons.sort_by_alpha),
                      SizedBox(width: 6),
                      if (isLocationAvailable) ...[
                        _buildSortChip(
                            'Auto Distance', 'distance', Icons.location_on),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!isLocationAvailable && !isLoadingLocation) ...[
            SizedBox(height: 8),
            _buildLocationPermissionRequest(),
            SizedBox(height: 8),
            _buildManualLocationInput(),
          ],
          if (isLocationAvailable) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stores automatically sorted by distance',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.green.shade700,
                          ),
                        ),
                        if (userLocation != null &&
                            !_isLocationInGhana(userLocation!.latitude,
                                userLocation!.longitude))
                          Text(
                            'Using default Accra location',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              color: Colors.orange.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationPermissionRequest() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.orange.shade600, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enable location to sort by distance',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _requestLocationPermission,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade500,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Enable',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (userLocation != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 12),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Location accuracy: ${userLocation!.accuracy.toStringAsFixed(0)}m',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _refreshLocation,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade500,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Refresh',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      final locationService = LocationService();
      locationService.clearCache(); // Clear cached location
      userLocation = await locationService.getCurrentLocation();

      if (userLocation != null) {
        debugPrint(
            '📍 Location refreshed: ${userLocation!.latitude}, ${userLocation!.longitude}');
        debugPrint('📍 Accuracy: ${userLocation!.accuracy}m');

        // Re-sort stores if distance sorting is active
        if (sortBy == 'distance') {
          setState(() {
            // This will trigger a rebuild and re-sort
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing location: $e');
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      await _initializeLocation();
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Widget _buildManualLocationInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location, color: Colors.blue.shade600, size: 16),
              SizedBox(width: 8),
              Text(
                'Or enter your location manually',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Accra, Ghana',
                    hintStyle: GoogleFonts.poppins(fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _geocodeLocation,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade500,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Find',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (manualLatitude != null && manualLongitude != null) ...[
            SizedBox(height: 4),
            Text(
              'Location set: ${manualLatitude!.toStringAsFixed(4)}, ${manualLongitude!.toStringAsFixed(4)}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.green.shade700,
              ),
            ),
          ],
          SizedBox(height: 8),
          Text(
            'Quick locations:',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
          SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildQuickLocationChip('Accra', 5.6037, -0.1870),
              _buildQuickLocationChip('Tema', 5.6795, -0.0167),
              _buildQuickLocationChip('Kumasi', 6.6885, -1.6244),
              _buildQuickLocationChip('Tamale', 9.4035, -0.8423),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _geocodeLocation() async {
    if (_locationController.text.trim().isEmpty) return;

    setState(() {
      isLoadingLocation = true;
    });

    try {
      final locationService = LocationService();
      final coordinates = await locationService
          .getCoordinatesFromAddress(_locationController.text.trim());

      if (coordinates != null) {
        setState(() {
          manualLatitude = coordinates['lat'];
          manualLongitude = coordinates['lon'];
          // Create a mock Position object for distance calculations
          userLocation = Position(
            latitude: coordinates['lat']!,
            longitude: coordinates['lon']!,
            timestamp: DateTime.now(),
            accuracy: 100.0, // Estimated accuracy for geocoded location
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          isLocationAvailable = true;
        });

        debugPrint(
            '📍 Manual location set: ${coordinates['lat']}, ${coordinates['lon']}');

        // Re-sort stores if distance sorting is active
        if (sortBy == 'distance') {
          setState(() {
            // This will trigger a rebuild and re-sort
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Could not find coordinates for "${_locationController.text}"'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error geocoding location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = sortBy == value;
    return GestureDetector(
      onTap: () {
        debugPrint('📍 Sort chip tapped: $value');
        setState(() {
          sortBy = value;
        });
        debugPrint('📍 sortBy updated to: $sortBy');

        // Force rebuild of the stores list
        setState(() {
          // This will trigger a rebuild and re-sort
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade500 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green.shade500 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade100,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLocationChip(String name, double lat, double lon) {
    return GestureDetector(
      onTap: () => _setQuickLocation(name, lat, lon),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  void _setQuickLocation(String name, double lat, double lon) {
    setState(() {
      manualLatitude = lat;
      manualLongitude = lon;
      _locationController.text = name;
      // Create a mock Position object for distance calculations
      userLocation = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 50.0, // Good accuracy for preset locations
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      isLocationAvailable = true;
    });

    debugPrint('📍 Quick location set: $name at $lat, $lon');

    // Test distance calculations with this location
    _testDistanceCalculation();

    // Re-sort stores if distance sorting is active
    if (sortBy == 'distance') {
      setState(() {
        // This will trigger a rebuild and re-sort
      });
    }
  }

  Widget _buildCompactDropdown({
    required dynamic value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
    bool isLoading = false,
    String? error,
    VoidCallback? onRetry,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value != null ? value['description'] : null,
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.green.shade300, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          suffixIcon: isLoading
              ? Container(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ),
                )
              : error != null
                  ? IconButton(
                      icon: Icon(Icons.refresh,
                          color: Colors.red.shade400, size: 20),
                      onPressed: onRetry,
                      tooltip: 'Retry',
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    )
                  : Icon(Icons.keyboard_arrow_down,
                      color: Colors.green.shade700, size: 22),
        ),
        hint: Text(hint,
            overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16)),
        isExpanded: true,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16),
            ),
          );
        }).toList(),
        onChanged: isLoading ? null : onChanged,
      ),
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
        // Distance sorting indicator
        if (sortBy == 'distance' && userLocation != null) ...[
          Container(
            margin: EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sort_by_alpha,
                  color: Colors.green.shade600,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stores sorted by distance from your location',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Closest stores appear first',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${filteredStores.length} stores',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Store list
        Expanded(
          child: ListView.builder(
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
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          color: Colors.white,
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: 200,
                          height: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 12,
                color: Colors.white,
              ),
              SizedBox(height: 8),
              Container(
                width: 150,
                height: 12,
                color: Colors.white,
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
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(dynamic store, int index) {
    final storeName = store['description'] ?? 'Unknown Store';
    final storeAddress = store['address'] ?? '';
    final storeHours = '8:00 AM - 8:00 PM';
    final isOpen = _isStoreOpen();
    // Get distance if available

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.green.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _launchMaps(storeName, storeAddress),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.green.shade50,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade200,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                storeName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.circle,
                                size: 12,
                                color: isOpen
                                    ? Colors.green.shade400
                                    : Colors.red.shade400,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isOpen
                                      ? [
                                          Colors.green.shade50,
                                          Colors.green.shade100
                                        ]
                                      : [
                                          Colors.red.shade50,
                                          Colors.red.shade100
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isOpen
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Text(
                                isOpen ? 'Open' : 'Closed',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOpen
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.location_on,
                                  size: 12, color: Colors.orange.shade500),
                            ),
                            SizedBox(width: 6),
                            if (store['region_name'] != null &&
                                store['city_name'] != null)
                              Expanded(
                                child: Text(
                                  '${store['city_name']}, ${store['region_name']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            // Show distance if available
                            if (store['distance'] != null &&
                                sortBy == 'distance')
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.straighten,
                                      size: 10,
                                      color: Colors.green.shade600,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      _formatDistance(store['distance']),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (storeAddress.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: 28),
                            child: Text(
                              storeAddress,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Store Hours
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.access_time,
                        size: 12, color: Colors.amber.shade500),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Hours',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    storeHours,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Action Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _launchMaps(storeName, storeAddress),
                  icon: Icon(Icons.directions, size: 16, color: Colors.white),
                  label: Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 100).ms)
        .slideY(begin: 0.2, end: 0);
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
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.green.shade800 : Colors.grey.shade800,
            ),
          ),
          subtitle: Text(
            'Tap to view stores',
            style: GoogleFonts.poppins(
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
      setState(() {
        citiesError = 'Network error: ${e.toString()}';
        isLoadingCities = false;
      });
    }
  }

  List<dynamic> _getFilteredAllStores() {
    debugPrint('📍 _getFilteredAllStores called - sortBy: $sortBy');

    final filteredStores = allStores.where((store) {
      // Filter by region if selected
      if (selectedRegion != null) {
        final storeRegion = store['region_name']?.toString() ?? '';
        final selectedRegionName =
            selectedRegion['description']?.toString() ?? '';
        if (storeRegion != selectedRegionName) {
          return false;
        }
      }

      // Filter by city if selected
      if (selectedCity != null) {
        final storeCity = store['city_name']?.toString() ?? '';
        final selectedCityName = selectedCity['description']?.toString() ?? '';
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
