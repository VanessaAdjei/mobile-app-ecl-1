// pages/delivery_page.dart
import 'dart:convert';
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/pages/savedaddresses.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'AppBackButton.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  _DeliveryPageState createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  String deliveryOption = 'Delivery';
  GoogleMapController? mapController;
  LatLng? selectedLocation;
  String? selectedAddress;
  double deliveryFee = 0.00;
  final TextEditingController _typeAheadController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Set<Marker> markers = {};
  bool isLoadingLocation = false;
  bool _isMapReady = false;
  Position? currentPosition;
  List<SavedAddress> savedAddresses = [];
  String? selectedRegion;
  String? selectedCity;
  List<String> availableStations = [];
  bool _highlightPhoneField = false;
  bool _highlightAddressField = false;
  bool _highlightPickupField = false;
  final GlobalKey addressSectionKey = GlobalKey();
  final GlobalKey pickupSectionKey = GlobalKey();
  final GlobalKey phoneSectionKey = GlobalKey();

  @override
  void dispose() {
    mapController?.dispose();
    _typeAheadController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSavedAddresses();
    });
  }

  double _calculateDeliveryFee(LatLng location) {
    if (selectedAddress?.toLowerCase().contains('accra') ?? false) {
      return 10.00;
    } else if (selectedAddress?.toLowerCase().contains('kumasi') ?? false) {
      return 15.00;
    } else {
      return 20.00;
    }
  }

  void _resetHighlights() {
    if (!mounted) return;
    setState(() {
      _highlightPhoneField = false;
      _highlightAddressField = false;
      _highlightPickupField = false;
    });
  }

  Future<void> _searchAddress(String address) async {
    if (!mounted || address.trim().isEmpty) return;

    setState(() => isLoadingLocation = true);
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty && mounted) {
        Location location = locations.first;
        LatLng latLng = LatLng(location.latitude, location.longitude);

        setState(() {
          selectedLocation = latLng;
          selectedAddress = address;
          markers = {
            Marker(
              markerId: const MarkerId('deliveryLocation'),
              position: latLng,
              infoWindow: InfoWindow(title: address),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            )
          };
          deliveryFee = _calculateDeliveryFee(latLng);
        });

        if (_isMapReady) {
          mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 15),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find location: $address')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingLocation = false);
      }
    }
  }

  void _showLocationError(String message,
      {bool showSettings = false, bool showManualEntry = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.white),
            ),
            if (showManualEntry) ...[
              SizedBox(height: 8),
              Text(
                'You can enter your address manually below.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: Duration(seconds: 8),
        action: SnackBarAction(
          label: showSettings ? 'Settings' : 'Try Again',
          textColor: Colors.white,
          onPressed: () {
            if (showSettings) {
              openAppSettings();
            } else {
              getCurrentLocation();
            }
          },
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> getCurrentLocation() async {
    if (!mounted) return;

    setState(() => isLoadingLocation = true);
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showLocationError(
          'Location services are disabled. Please enable location services to get your current location.',
          showSettings: true,
        );
        return;
      }

      // Check location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _showLocationError(
            'Location permission is required to get your current location.',
            showSettings: true,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showLocationError(
          'Location permissions are permanently denied. Please enable them in settings.',
          showSettings: true,
        );
        return;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
              'Location request timed out. Please try again or enter your address manually.');
        },
      );

      if (!mounted) return;
      setState(() => currentPosition = position);

      // Update map if ready
      if (_isMapReady) {
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
      }

      // Get address from coordinates
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final address = [
            place.street,
            place.locality,
            place.administrativeArea
          ].where((s) => s?.isNotEmpty ?? false).join(', ');

          _typeAheadController.text = address;
          await _searchAddress(address);
        }
      } catch (e) {
        if (mounted) {
          _showLocationError(
            'Could not get address from coordinates.',
            showManualEntry: true,
          );
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showLocationError(
          'Location request timed out.',
          showManualEntry: true,
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        String message = 'Error getting location: ';
        switch (e.code) {
          case 'PERMISSION_DENIED':
            message = 'Location permission denied.';
            break;
          case 'LOCATION_SERVICE_DISABLED':
            message = 'Location services are disabled.';
            break;
          case 'LOCATION_SERVICE_UNAVAILABLE':
            message = 'Location services are unavailable.';
            break;
          default:
            message += e.message ?? 'Unknown error';
        }
        _showLocationError(
          message,
          showSettings: e.code == 'PERMISSION_DENIED' ||
              e.code == 'LOCATION_SERVICE_DISABLED',
          showManualEntry: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showLocationError(
          'Error getting location.',
          showManualEntry: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Custom header (modernized)
              Animate(
                effects: [
                  FadeEffect(duration: 400.ms),
                  SlideEffect(
                      duration: 400.ms,
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0))
                ],
                child: Container(
                  padding: EdgeInsets.only(top: topPadding),
                  color: theme.appBarTheme.backgroundColor ??
                      Colors.green.shade700,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AppBackButton(
                            backgroundColor: theme.primaryColor,
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  _buildProgressStep("Cart",
                                      isActive: false,
                                      isCompleted: true,
                                      step: 1),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Delivery",
                                      isActive: true,
                                      isCompleted: false,
                                      step: 2),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Payment",
                                      isActive: false,
                                      isCompleted: false,
                                      step: 3),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Confirmation",
                                      isActive: false,
                                      isCompleted: false,
                                      step: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildDeliveryOptions(),
                              ),
                              const SizedBox(height: 16),
                              if (deliveryOption == 'Delivery')
                                Animate(
                                  effects: [
                                    FadeEffect(duration: 400.ms),
                                    SlideEffect(
                                        duration: 400.ms,
                                        begin: Offset(0, 0.1),
                                        end: Offset(0, 0))
                                  ],
                                  child: _buildMapSection(),
                                ),
                              if (deliveryOption == 'Pickup')
                                Animate(
                                  effects: [
                                    FadeEffect(duration: 400.ms),
                                    SlideEffect(
                                        duration: 400.ms,
                                        begin: Offset(0, 0.1),
                                        end: Offset(0, 0))
                                  ],
                                  child: _buildPickupForm(),
                                ),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildContactInfo(),
                              ),
                              const SizedBox(height: 16),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildDeliveryNotes(),
                              ),
                              const SizedBox(height: 20),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildOrderSummary(cart),
                              ),
                              const SizedBox(height: 30),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildContinueButton(),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                        if (isLoadingLocation)
                          Center(
                              child: CircularProgressIndicator(
                                  color: theme.primaryColor)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 1,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProgressStep(String text,
      {required bool isActive, required bool isCompleted, required int step}) {
    final color = isCompleted
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight:
                isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'DELIVERY METHOD',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Home Delivery'),
                  selected: deliveryOption == 'Delivery',
                  onSelected: (selected) =>
                      _handleDeliveryOptionChange('Delivery'),
                  selectedColor: Colors.green.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: deliveryOption == 'Delivery'
                        ? Colors.green
                        : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Pickup Station'),
                  selected: deliveryOption == 'Pickup',
                  onSelected: (selected) =>
                      _handleDeliveryOptionChange('Pickup'),
                  selectedColor: Colors.green.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: deliveryOption == 'Pickup'
                        ? Colors.green
                        : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (deliveryOption == 'Delivery')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.my_location, size: 20),
              label: const Text('Use Current Location'),
              onPressed: getCurrentLocation,
            ),
          ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Column(
      key: addressSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ENTER YOUR DELIVERY ADDRESS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _typeAheadController,
            decoration: InputDecoration(
              hintText: 'Search for your address',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _typeAheadController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _typeAheadController.clear();
                        setState(() {
                          selectedLocation = null;
                          selectedAddress = null;
                          markers.clear();
                        });
                      },
                    )
                  : null,
              focusedBorder: _highlightAddressField
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              enabledBorder: _highlightAddressField
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
            ),
            onSubmitted: (value) async {
              if (value.length > 2) {
                await _searchAddress(value);
                setState(() {
                  _highlightAddressField = false;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        if (savedAddresses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<SavedAddress>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Use Saved Address",
                border: OutlineInputBorder(),
              ),
              items: savedAddresses.map((addr) {
                return DropdownMenuItem(
                  value: addr,
                  child: Text(addr.address),
                );
              }).toList(),
              onChanged: (selected) {
                if (selected != null) {
                  setState(() {
                    selectedLocation = selected.location;
                    selectedAddress = selected.address;
                    _typeAheadController.text = selected.address;
                    markers = {
                      Marker(
                        markerId: const MarkerId('deliveryLocation'),
                        position: selected.location,
                        infoWindow: InfoWindow(title: selected.address),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                      )
                    };
                    deliveryFee = _calculateDeliveryFee(selected.location);
                  });

                  if (_isMapReady) {
                    mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(selected.location, 15),
                    );
                  }
                }
              },
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 250,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentPosition != null
                        ? LatLng(currentPosition!.latitude,
                            currentPosition!.longitude)
                        : const LatLng(5.6037, -0.1870),
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    mapController = controller;
                    setState(() => _isMapReady = true);
                    if (currentPosition != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(
                            currentPosition!.latitude,
                            currentPosition!.longitude,
                          ),
                          15,
                        ),
                      );
                    }
                  },
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  onTap: (latLng) async {
                    try {
                      final placemarks = await placemarkFromCoordinates(
                        latLng.latitude,
                        latLng.longitude,
                      );

                      if (placemarks.isNotEmpty && mounted) {
                        final place = placemarks.first;
                        final address = [
                          place.street,
                          place.locality,
                          place.administrativeArea
                        ].where((s) => s?.isNotEmpty ?? false).join(', ');

                        setState(() {
                          _typeAheadController.text = address;
                          selectedLocation = latLng;
                          selectedAddress = address;
                          markers = {
                            Marker(
                              markerId: const MarkerId('selected_location'),
                              position: latLng,
                              infoWindow: InfoWindow(title: address),
                            )
                          };
                          deliveryFee = _calculateDeliveryFee(latLng);
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  },
                ),
                if (!_isMapReady || isLoadingLocation)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (selectedAddress != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECTED ADDRESS:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  selectedAddress!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivery Fee: GHS ${deliveryFee.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPickupForm() {
    final Map<String, Map<String, List<String>>> pickupLocations = {
      'Greater Accra': {
        'Accra': ['Accra Mall', 'West Hills Mall', 'Achimota Retail Centre'],
        'Tema': ['Tema Mall', 'Community 25 Station']
      },
      'Ashanti': {
        'Kumasi': ['Kumasi City Mall', 'Adum Station', 'Asokwa Station']
      },
      'Western': {
        'Takoradi': ['Takoradi Mall', 'Airport Station']
      },
      'Eastern': {
        'Madina': ['Madina Mall'],
        'Koforidua': ['Koforidua Station']
      }
    };

    return Padding(
      key: pickupSectionKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PICKUP LOCATION',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedRegion,
            decoration: InputDecoration(
              labelText: 'Select Region',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              focusedBorder: _highlightPickupField
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              enabledBorder: _highlightPickupField
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              labelStyle:
                  _highlightPickupField ? TextStyle(color: Colors.red) : null,
            ),
            items: pickupLocations.keys.map((region) {
              return DropdownMenuItem(
                value: region,
                child: Text(region),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedRegion = value;
                selectedCity = null;
                selectedAddress = null;
              });
            },
          ),
          if (selectedRegion != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCity,
              decoration: const InputDecoration(
                labelText: 'Select City',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: pickupLocations[selectedRegion]!.keys.map((city) {
                return DropdownMenuItem(
                  value: city,
                  child: Text(city),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value;
                  selectedAddress = null;
                });
              },
            ),
          ],
          if (selectedCity != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedAddress,
              decoration: const InputDecoration(
                labelText: 'Select Pickup Station',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: pickupLocations[selectedRegion]![selectedCity]!
                  .map((station) {
                return DropdownMenuItem(
                  value: station,
                  child: Text(station),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedAddress = value;
                  deliveryFee = 0.00;
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Pickup stations are open Monday-Saturday, 9am-6pm',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    bool isPhoneValid =
        _phoneController.text.length == 10 || _phoneController.text.isEmpty;

    return Padding(
      key: phoneSectionKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTACT INFORMATION',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            buildCounter: (BuildContext context,
                {required int currentLength,
                required bool isFocused,
                required int? maxLength}) {
              return Text(
                '${currentLength}/$maxLength',
                style: TextStyle(
                  color:
                      currentLength == maxLength ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              );
            },
            onChanged: (value) {
              setState(() {
                _highlightPhoneField = false;
              });
            },
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: const OutlineInputBorder(),
              errorText: isPhoneValid ? null : 'Phone number must be 10 digits',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('🇬🇭', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 4),
                    Text('+233', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              focusedBorder: _highlightPhoneField
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              enabledBorder: _highlightPhoneField
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              labelStyle:
                  _highlightPhoneField ? TextStyle(color: Colors.red) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryNotes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DELIVERY NOTES (OPTIONAL)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Any special delivery instructions?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final subtotal = cart.calculateSubtotal();
    final total = subtotal + deliveryFee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', subtotal),
          _buildSummaryRow('Delivery Fee', deliveryFee),
          const Divider(),
          _buildSummaryRow('TOTAL', total, isHighlighted: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'GHS ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: () async {
            await saveCurrentAddress();

            bool isValid = true;

            // Validate delivery/pickup address
            if (deliveryOption == 'Delivery' && selectedAddress == null) {
              setState(() {
                _highlightAddressField = true;
                isValid = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Scrollable.ensureVisible(
                  addressSectionKey.currentContext!,
                  alignment: 0.5,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              });
            } else if (deliveryOption == 'Pickup' && selectedAddress == null) {
              setState(() {
                _highlightPickupField = true;
                isValid = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Scrollable.ensureVisible(
                  pickupSectionKey.currentContext!,
                  alignment: 0.5,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              });
            }

            // Validate phone number
            if (_phoneController.text.isEmpty) {
              setState(() {
                _highlightPhoneField = true;
                isValid = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Scrollable.ensureVisible(
                  phoneSectionKey.currentContext!,
                  alignment: 0.5,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              });
            } else if (_phoneController.text.length != 10) {
              setState(() {
                _highlightPhoneField = true;
                isValid = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Scrollable.ensureVisible(
                  phoneSectionKey.currentContext!,
                  alignment: 0.5,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              });
            }

            if (!isValid) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please fill all required fields')),
              );
              return;
            }

            // Save all delivery information to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userPhoneNumber', _phoneController.text);
            await prefs.setString('delivery_address', selectedAddress!);
            await prefs.setString('delivery_option', deliveryOption);
            await prefs.setString('order_status', 'Processing');

            // Print saved information for verification
            print('=== Saved Delivery Information ===');
            print('Phone Number: ${_phoneController.text}');
            print('Delivery Address: $selectedAddress');
            print('Delivery Option: $deliveryOption');
            print('Order Status: Processing');
            print('===============================');

            // Navigate to payment page with delivery details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentPage(
                  deliveryAddress: selectedAddress,
                  contactNumber: _phoneController.text,
                  deliveryOption: deliveryOption,
                ),
              ),
            );
          },
          child: const Text(
            'CONTINUE TO PAYMENT',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _handleDeliveryOptionChange(String option) {
    _resetHighlights();
    setState(() {
      deliveryOption = option;
      if (option == 'Pickup') {
        selectedLocation = null;
        _typeAheadController.clear();
        markers.clear();
        deliveryFee = 0.00;
      }
    });
  }

  Future<void> loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getStringList('saved_addresses') ?? [];

    setState(() {
      savedAddresses = savedData
          .map((jsonStr) => SavedAddress.fromJson(json.decode(jsonStr)))
          .toList();
    });
  }

  Future<void> saveCurrentAddress() async {
    if (selectedAddress == null || selectedLocation == null) return;

    final newAddress = SavedAddress(
      address: selectedAddress!,
      location: selectedLocation!,
    );
    bool addressExists = savedAddresses.any((addr) =>
        addr.address == newAddress.address ||
        (addr.location.latitude == newAddress.location.latitude &&
            addr.location.longitude == newAddress.location.longitude));

    if (!addressExists) {
      setState(() {
        savedAddresses.add(newAddress);
      });

      final prefs = await SharedPreferences.getInstance();
      final savedData =
          savedAddresses.map((e) => json.encode(e.toJson())).toList();
      await prefs.setStringList('saved_addresses', savedData);
    }
  }
}
