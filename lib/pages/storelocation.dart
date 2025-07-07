// pages/storelocation.dart
import 'package:flutter/material.dart';
import 'bottomnav.dart';
import 'AppBackButton.dart';
import 'HomePage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/delivery_service.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  _StoreSelectionPageState createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage>
    with TickerProviderStateMixin {
  // API Data
  List<dynamic> regions = [];
  List<dynamic> cities = [];
  List<dynamic> stores = [];
  List<dynamic> allStores = [];

  // Selected values
  dynamic selectedRegion;
  dynamic selectedCity;

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Load regions from API
  Future<void> _loadRegions() async {
    print('=== STORE LOCATION: Loading regions ===');
    setState(() {
      isLoadingRegions = true;
      regionsError = null;
    });

    try {
      print('Calling DeliveryService.getRegions()...');
      final result = await DeliveryService.getRegions();
      print('Regions API result: $result');

      if (result['success']) {
        final regionsData = result['data'] ?? [];
        print('Regions data received: ${regionsData.length} regions');
        print('Regions: $regionsData');

        setState(() {
          regions = regionsData;
          isLoadingRegions = false;
        });
        print('Regions loaded successfully: ${regions.length} regions');
      } else {
        print('Regions API failed: ${result['message']}');
        setState(() {
          regionsError = result['message'] ?? 'Failed to load regions';
          isLoadingRegions = false;
        });
      }
    } catch (e) {
      print('Error loading regions: $e');
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
    print('=== STORE LOCATION: Loading ALL stores ===');
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
            allStoresList.add(store);
          }
        }
      }

      setState(() {
        allStores = allStoresList;
        isLoadingAllStores = false;
      });
      print('ALL stores loaded successfully: ${allStores.length} stores');
    } catch (e) {
      print('Error loading all stores: $e');
      setState(() {
        allStoresError = 'Network error: ${e.toString()}';
        isLoadingAllStores = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        centerTitle: Theme.of(context).appBarTheme.centerTitle,
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          },
        ),
        title: Text(
          'Store Locations',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              _buildHeaderSection(),
              Expanded(
                child: _buildStoreList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade100,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green.shade600, size: 20),
                SizedBox(width: 6),
                Text(
                  'Find a Store',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
            SizedBox(height: 8),
            _buildSearchAndFilterCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterCard() {
    return Card(
      elevation: 1,
      shadowColor: Colors.green.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.green.shade50,
            ],
          ),
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
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0);
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
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 9),
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
          contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          suffixIcon: isLoading
              ? Container(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ),
                )
              : error != null
                  ? IconButton(
                      icon: Icon(Icons.refresh,
                          color: Colors.red.shade400, size: 12),
                      onPressed: onRetry,
                      tooltip: 'Retry',
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    )
                  : Icon(Icons.keyboard_arrow_down,
                      color: Colors.green.shade700, size: 14),
        ),
        hint: Text(hint,
            overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9)),
        isExpanded: true,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9),
            ),
          );
        }).toList(),
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget _buildStoreList() {
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

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredStores.length,
      itemBuilder: (context, index) {
        final store = filteredStores[index];
        return _buildStoreCard(store, index);
      },
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
    final storeRating = (store['rating'] ?? 0.0).toDouble();

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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeAddress,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (store['region_name'] != null &&
                                      store['city_name'] != null)
                                    Text(
                                      '${store['city_name']}, ${store['region_name']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
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

  Widget _buildRegionCitySelection() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Header
        Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.store, color: Colors.green.shade600, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select a region and city to view stores',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Regions List
        ...regions.map((region) => _buildRegionCard(region)).toList(),
      ],
    );
  }

  Widget _buildRegionCard(dynamic region) {
    final regionName = region['description'] ?? 'Unknown Region';
    final isExpanded =
        selectedRegion != null && selectedRegion['id'] == region['id'];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.location_city, color: Colors.green.shade600),
        title: Text(
          regionName,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Tap to view cities',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        children: [
          if (isExpanded) _buildCitiesList(region),
        ],
        onExpansionChanged: (expanded) {
          if (expanded) {
            setState(() {
              selectedRegion = region;
              selectedCity = null;
              stores = [];
            });
            _loadCities(region);
          } else {
            setState(() {
              selectedRegion = null;
              selectedCity = null;
              stores = [];
            });
          }
        },
      ),
    );
  }

  Widget _buildCitiesList(dynamic region) {
    if (isLoadingCities) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: Colors.green.shade600),
        ),
      );
    }

    if (citiesError != null) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Error loading cities: $citiesError',
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _loadCities(region),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (cities.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text(
          'No cities found in this region',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: cities.map((city) => _buildCityCard(city)).toList(),
    );
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
    return allStores.where((store) {
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
  }

  List<dynamic> _getFilteredStores() {
    return stores;
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
