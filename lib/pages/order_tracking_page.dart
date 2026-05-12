// pages/order_tracking_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/delivery_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'app_back_button.dart';

class OrderTrackingPage extends StatefulWidget {
  final Map<String, dynamic> orderDetails;

  const OrderTrackingPage({
    super.key,
    required this.orderDetails,
  });

  @override
  OrderTrackingPageState createState() => OrderTrackingPageState();
}

class OrderTrackingPageState extends State<OrderTrackingPage> {
  static const double _kTrackRadius = 20;

  String? _deliveryAddress;
  String? _contactNumber;
  String? _deliveryOption;
  bool _isLoading = true;
  double? _actualTotalAmount; // Store actual total fetched from API if needed
  double?
      _actualDeliveryFee; // Store actual delivery fee fetched from API if needed
  /// Current order status for timeline; updated from API so progression can move.
  String? _orderStatus;

  /// Timer for periodic order status refresh while page is open
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 30);

  /// Shown in the track-order sliver header (toolbar + expanded): order id only.
  String _sliverHeaderOrderLabel() {
    final o = widget.orderDetails;
    final raw = o['order_number']?.toString() ??
        o['delivery_id']?.toString() ??
        o['transaction_id']?.toString() ??
        o['order_id']?.toString() ??
        o['id']?.toString() ??
        '';
    final t = raw.trim();
    if (t.isEmpty || t.toUpperCase() == 'N/A') return 'Order';
    return t.startsWith('#') ? t : '#$t';
  }

  bool _isPickupOrder() {
    bool mentionsPickup(String? v) {
      final n = (v ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      return n.contains('pickup') ||
          n.contains('instore') ||
          n.contains('instorepickup') ||
          n == 'collect';
    }

    final o = widget.orderDetails;
    final candidates = <String?>[
      _deliveryOption,
      o['delivery_option']?.toString(),
      o['shipping_type']?.toString(),
      o['shipping_method']?.toString(),
      o['delivery_method']?.toString(),
      o['shipping']?.toString(),
      o['fulfillment_type']?.toString(),
      o['order_type']?.toString(),
    ];
    if (candidates.any(mentionsPickup)) return true;

    for (final k in [
      'pickup_site',
      'pickup_location',
      'pickup_city',
      'pickup_region',
    ]) {
      if ((o[k]?.toString().trim().isNotEmpty ?? false)) return true;
    }

    final addr1 = o['addr_1']?.toString().toLowerCase().trim() ?? '';
    if (addr1 == 'pickup order' || addr1.contains('pickup')) return true;

    final addr =
        (o['delivery_address'] ?? o['shipping_address'] ?? o['address'] ?? '')
            .toString()
            .toLowerCase();
    if (addr.contains('pickup at') ||
        addr.startsWith('pickup ') ||
        addr.contains(' collect at')) {
      return true;
    }

    return false;
  }

  String _pickupLocationSummary() {
    final o = widget.orderDetails;
    final parts = <String>[];
    void add(dynamic raw) {
      if (raw == null) return;
      final s = raw.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'pickup order') return;
      if (!parts.contains(s)) parts.add(s);
    }

    add(o['pickup_site']);
    add(o['pickup_location']);
    add(o['pickup_city']);
    add(o['pickup_region']);
    if (parts.isNotEmpty) return parts.join(' · ');
    final addr = _deliveryAddress?.trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return 'Not available';
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 OrderTrackingPage initState called');
    debugPrint('🔍 Order details in initState: ${widget.orderDetails}');
    debugPrint(
        '🔍 All order details keys: ${widget.orderDetails.keys.toList()}');
    // Log delivery fee related fields
    debugPrint('🔍 Delivery fee fields check:');
    debugPrint('🔍   delivery_fee: ${widget.orderDetails['delivery_fee']}');
    debugPrint('🔍   deliveryFee: ${widget.orderDetails['deliveryFee']}');
    debugPrint('🔍   total_price: ${widget.orderDetails['total_price']}');
    debugPrint('🔍   amount: ${widget.orderDetails['amount']}');
    debugPrint(
        'Current navigation stack depth: ${Navigator.of(context).widget.observers.length}');
    debugPrint('Can pop current context: ${Navigator.canPop(context)}');
    _loadDeliveryInfo();

    // If delivery fee is missing, try to retrieve it from stored preferences
    final hasDeliveryFee = widget.orderDetails['delivery_fee'] != null ||
        widget.orderDetails['deliveryFee'] != null;
    if (!hasDeliveryFee) {
      debugPrint(
          '🔍 Delivery fee missing - trying to retrieve from stored data...');
      _loadStoredDeliveryFee();
    }

    // Start periodic refresh so order status updates automatically while page is open
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) _loadDeliveryInfo();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  Future<void> _loadDeliveryInfo() async {
    try {
      debugPrint('🔍 Loading delivery info for order tracking...');
      debugPrint('🔍 Order details available: ${widget.orderDetails}');
      final isLoggedIn = await AuthService.isLoggedIn();
      debugPrint('🔍 User logged in: $isLoggedIn');

      final orderDetails = widget.orderDetails;

      String? notificationAddress =
          orderDetails['delivery_address']?.toString() ??
              orderDetails['shipping_address']?.toString() ??
              orderDetails['address']?.toString() ??
              orderDetails['addr_1']?.toString() ??
              orderDetails['region']?.toString() ??
              orderDetails['city']?.toString();

      String? notificationContact =
          orderDetails['contact_number']?.toString() ??
              orderDetails['phone']?.toString() ??
              orderDetails['user_phone']?.toString() ??
              orderDetails['user_phone_number']?.toString();

      String? notificationDeliveryOption =
          orderDetails['delivery_option']?.toString() ??
              orderDetails['shipping_method']?.toString() ??
              orderDetails['delivery_method']?.toString() ??
              orderDetails['shipping_type']?.toString();

      debugPrint('🔍 Delivery info from notification:');
      debugPrint('🔍 Address: $notificationAddress');
      debugPrint('🔍 Contact: $notificationContact');
      debugPrint('🔍 Option: $notificationDeliveryOption');

      debugPrint('🔍 All available fields in order details:');
      orderDetails.forEach((key, value) {
        if (key.toString().toLowerCase().contains('address') ||
            key.toString().toLowerCase().contains('phone') ||
            key.toString().toLowerCase().contains('delivery') ||
            key.toString().toLowerCase().contains('shipping')) {
          debugPrint('🔍 $key: $value');
        }
      });

      if (notificationAddress == null || notificationAddress.isEmpty) {
        final region = orderDetails['region']?.toString();
        final city = orderDetails['city']?.toString();
        final addr1 = orderDetails['addr_1']?.toString();

        if (region != null || city != null || addr1 != null) {
          final addressParts = <String>[];
          if (addr1 != null && addr1.isNotEmpty) addressParts.add(addr1);
          if (city != null && city.isNotEmpty) addressParts.add(city);
          if (region != null && region.isNotEmpty) addressParts.add(region);

          if (addressParts.isNotEmpty) {
            notificationAddress = addressParts.join(', ');
            debugPrint('🔍 Constructed delivery address: $notificationAddress');
          }
        }
      }

      // if we dont have delivery info from notification, try getting it from the api
      if (notificationAddress == null || notificationAddress.isEmpty) {
        if (isLoggedIn) {
          debugPrint(
              '🔍 No delivery address in notification, trying to fetch from API...');

          // check if we have a delivery_id we can use
          final deliveryId = orderDetails['delivery_id']?.toString();
          if (deliveryId != null && deliveryId.isNotEmpty) {
            debugPrint(
                '🔍 Found delivery_id: $deliveryId - this might contain delivery info');
          }

          // first try to get delivery info from their saved address
          debugPrint('🔍 Trying to fetch user\'s saved delivery info...');
          final deliveryResult = await DeliveryService.getLastDeliveryInfo();

          if (deliveryResult['success'] && deliveryResult['data'] != null) {
            final deliveryData = deliveryResult['data'];
            debugPrint('🔍 Successfully fetched delivery info: $deliveryData');

            // get delivery info from the saved data
            final savedAddress = deliveryData['address']?.toString() ??
                deliveryData['addr_1']?.toString();
            final savedRegion = deliveryData['region']?.toString();
            final savedCity = deliveryData['city']?.toString();

            if (savedAddress != null && savedAddress.isNotEmpty) {
              notificationAddress = savedAddress;
              debugPrint(
                  '🔍 Found saved delivery address: $notificationAddress');
            } else if (savedRegion != null || savedCity != null) {
              final addressParts = <String>[];
              if (savedAddress != null && savedAddress.isNotEmpty)
                addressParts.add(savedAddress);
              if (savedCity != null && savedCity.isNotEmpty)
                addressParts.add(savedCity);
              if (savedRegion != null && savedRegion.isNotEmpty)
                addressParts.add(savedRegion);

              if (addressParts.isNotEmpty) {
                notificationAddress = addressParts.join(', ');
                debugPrint(
                    '🔍 Constructed address from saved delivery info: $notificationAddress');
              }
            }

            // get contact info
            final savedContact = deliveryData['phone']?.toString();
            if (savedContact != null && savedContact.isNotEmpty) {
              notificationContact = savedContact;
              debugPrint('🔍 Found saved contact number: $notificationContact');
            }

            // get delivery option
            final savedDeliveryOption =
                deliveryData['delivery_option']?.toString() ??
                    deliveryData['shipping_type']?.toString();
            if (savedDeliveryOption != null && savedDeliveryOption.isNotEmpty) {
              notificationDeliveryOption = savedDeliveryOption;
              debugPrint(
                  '🔍 Found saved delivery option: $notificationDeliveryOption');
            }
          } else {
            debugPrint('🔍 No saved delivery info found, trying orders API...');
            await _fetchOrderDetailsFromAPI();
          }
        } else {
          debugPrint(
              '🔍 User not logged in, cannot fetch delivery details from API');
          debugPrint('🔍 Delivery details will show default values');
        }
      }

      // if we still dont have delivery info, try shared preferences
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _deliveryAddress = notificationAddress ??
            prefs.getString('delivery_address') ??
            'Address not available';
        _contactNumber = notificationContact ??
            prefs.getString('userPhoneNumber') ??
            'Contact not available';
        _deliveryOption = notificationDeliveryOption ??
            prefs.getString('delivery_option') ??
            'Standard Delivery';
        _orderStatus =
            widget.orderDetails['status']?.toString() ?? 'Processing';
        _isLoading = false;
      });

      // Fetch latest order status from API so delivery progression timeline can move
      if (isLoggedIn) {
        await _fetchOrderDetailsFromAPI();
      }

      debugPrint('🔍 Final delivery info loaded:');
      debugPrint('🔍 Address: $_deliveryAddress');
      debugPrint('🔍 Contact: $_contactNumber');
      debugPrint('🔍 Option: $_deliveryOption');
    } catch (e) {
      debugPrint('Error loading delivery info: $e');
      setState(() {
        _deliveryAddress = 'Address not available';
        _contactNumber = 'Contact not available';
        _deliveryOption = 'Standard Delivery';
        _orderStatus =
            widget.orderDetails['status']?.toString() ?? 'Processing';
        _isLoading = false;
      });
    }
  }

  // Load delivery fee from SharedPreferences if it was stored when order was placed
  Future<void> _loadStoredDeliveryFee() async {
    try {
      final transactionId = widget.orderDetails['transaction_id']?.toString() ??
          widget.orderDetails['delivery_id']?.toString() ??
          widget.orderDetails['order_id']?.toString();

      if (transactionId == null || transactionId.isEmpty) {
        debugPrint('🔍 Cannot load stored delivery fee: no transaction_id');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Try with the transaction_id/delivery_id as-is (could be ECL format)
      String deliveryFeeKey = 'order_delivery_fee_$transactionId';
      String totalKey = 'order_total_$transactionId';

      double? storedDeliveryFee = prefs.getDouble(deliveryFeeKey);
      double? storedTotal = prefs.getDouble(totalKey);

      // If not found and transactionId is ECL format, also try with ORDER_ prefix
      // (in case it was stored with ORDER_ prefix from confirmation page)
      if (storedDeliveryFee == null && transactionId.startsWith('ECL')) {
        // Extract the numeric part from ECL format (timestamp + random chars)
        final eclNumericPart = transactionId.replaceFirst('ECL', '');
        // Try to find ORDER_ prefixed version by checking all keys
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith('order_delivery_fee_ORDER_')) {
            // Extract numeric part from ORDER_ key
            final orderNumericPart =
                key.replaceFirst('order_delivery_fee_ORDER_', '');
            // Try matching with different lengths (ECL might have shorter timestamp)
            // Match if ORDER_ timestamp starts with ECL timestamp (or vice versa)
            final minLength = eclNumericPart.length < orderNumericPart.length
                ? eclNumericPart.length
                : orderNumericPart.length;
            if (minLength >= 10) {
              // Try matching first 10 digits (common timestamp length)
              final eclPrefix =
                  eclNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              final orderPrefix = orderNumericPart.substring(
                  0, minLength > 10 ? 10 : minLength);
              if (eclPrefix == orderPrefix) {
                deliveryFeeKey = key;
                storedDeliveryFee = prefs.getDouble(key);
                debugPrint(
                    '🔍 Found delivery fee with ORDER_ prefix: $key (matched by timestamp prefix)');
                break;
              }
            }
          }
        }
      }

      // If still not found, try the reverse: if we have ORDER_ prefix, try ECL format
      if (storedDeliveryFee == null && transactionId.startsWith('ORDER_')) {
        final orderNumericPart = transactionId.replaceFirst('ORDER_', '');
        // Try to find ECL format by searching for keys with matching timestamp prefix
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith('order_delivery_fee_ECL')) {
            // Extract numeric part from ECL key
            final eclNumericPart =
                key.replaceFirst('order_delivery_fee_ECL', '');
            // Try matching with different lengths
            final minLength = eclNumericPart.length < orderNumericPart.length
                ? eclNumericPart.length
                : orderNumericPart.length;
            if (minLength >= 10) {
              // Try matching first 10 digits (common timestamp length)
              final eclPrefix =
                  eclNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              final orderPrefix = orderNumericPart.substring(
                  0, minLength > 10 ? 10 : minLength);
              if (eclPrefix == orderPrefix) {
                deliveryFeeKey = key;
                storedDeliveryFee = prefs.getDouble(key);
                debugPrint(
                    '🔍 Found delivery fee with ECL format: $key (matched by timestamp prefix)');
                break;
              }
            }
          }
        }
      }

      if (storedDeliveryFee != null && storedDeliveryFee > 0) {
        debugPrint(
            '🔍 ✅ Found stored delivery fee: $storedDeliveryFee for order $transactionId');
        // Also get the total if available
        if (storedTotal == null) {
          totalKey = deliveryFeeKey.replaceFirst(
              'order_delivery_fee_', 'order_total_');
          storedTotal = prefs.getDouble(totalKey);
        }

        if (mounted) {
          setState(() {
            _actualDeliveryFee = storedDeliveryFee;
            if (storedTotal != null && storedTotal > 0) {
              _actualTotalAmount = storedTotal;
            }
          });
        }
      } else {
        debugPrint('🔍 No stored delivery fee found for order $transactionId');
        debugPrint('🔍 Tried key: $deliveryFeeKey');
      }
    } catch (e) {
      debugPrint('🔍 Error loading stored delivery fee: $e');
    }
  }

  /// Fallback: fetch status directly from /api/orders/{id}/status when order not in list
  Future<String?> _fetchStatusDirectly(String? orderId) async {
    if (orderId == null || orderId.isEmpty) return null;
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse(ApiConfig.getOrderStatusUrl(orderId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status']?.toString() ??
            data['data']?['status']?.toString();
      }
    } catch (e) {
      debugPrint('🔍 Direct status API error: $e');
    }
    return null;
  }

  // try to get order details from api to find delivery info
  Future<void> _fetchOrderDetailsFromAPI() async {
    try {
      final orderId = widget.orderDetails['id']?.toString();
      final orderNumber = widget.orderDetails['order_number']?.toString();

      if (orderId == null && orderNumber == null) {
        debugPrint('🔍 No order ID or number available for API call');
        return;
      }

      debugPrint(
          '🔍 Fetching order details from API for order: $orderId / $orderNumber');

      debugPrint('🔍 Fetching orders via AuthService...');
      final result = await AuthService.getOrders();

      if (result['status'] == 'success' && result['data'] is List) {
        final orders = result['data'] as List;
        final notificationDeliveryId =
            widget.orderDetails['delivery_id']?.toString() ??
                widget.orderDetails['transaction_id']?.toString() ??
                widget.orderDetails['id']?.toString() ??
                widget.orderDetails['order_number']?.toString();

        debugPrint('🔍 Orders API response received, ${orders.length} orders');

        // Try direct status API first (most reliable for notification flow)
        final directStatus = await _fetchStatusDirectly(
            notificationDeliveryId ?? orderId ?? orderNumber);
        if (directStatus != null && directStatus.isNotEmpty && mounted) {
          setState(() => _orderStatus = directStatus);
          debugPrint('🔍 Status from direct API: $directStatus');
        }

        // print what we're looking for
        debugPrint('🔍 Looking for order with:');
        debugPrint('🔍   - orderId: $orderId');
        debugPrint('🔍   - orderNumber: $orderNumber');
        debugPrint('🔍   - delivery_id: $notificationDeliveryId');

        if (orders.isNotEmpty) {
          debugPrint('🔍 Sample orders from API:');
          for (int i = 0; i < orders.length && i < 5; i++) {
            final order = orders[i];
            debugPrint(
                '🔍 Order ${i + 1}: ID=${order['id']}, Delivery ID=${order['delivery_id']}, status=${order['status']}');
          }
        }

        // try different ways to find the order (use toString() for type-safe comparison)
        Map<String, dynamic>? targetOrder;

        for (final order in orders) {
          final dId = order['delivery_id']?.toString();
          final tId = order['transaction_id']?.toString();
          final oId = order['id']?.toString();
          final ordNum = order['order_number']?.toString();
          final match = (dId != null &&
                  (dId == notificationDeliveryId || dId == orderNumber)) ||
              (tId != null &&
                  (tId == notificationDeliveryId || tId == orderNumber)) ||
              (oId != null &&
                  (oId == orderId || oId == notificationDeliveryId)) ||
              (ordNum != null && (ordNum == orderId || ordNum == orderNumber));
          if (match) {
            targetOrder = Map<String, dynamic>.from(order);
            debugPrint(
                '🔍 Found order (delivery_id=$dId, status=${order['status']})');
            break;
          }
        }

        if (targetOrder == null &&
            orderId != null &&
            orderId.startsWith('ORDER_')) {
          final numericId = orderId.replaceFirst('ORDER_', '');
          final numericIdInt = int.tryParse(numericId);
          if (numericIdInt != null) {
            for (final order in orders) {
              if (order['id'] == numericIdInt ||
                  order['id'].toString() == numericId) {
                targetOrder = Map<String, dynamic>.from(order);
                debugPrint('🔍 Found order by numeric ID');
                break;
              }
            }
          }
        }

        if (targetOrder != null) {
          debugPrint('🔍 Found target order in orders list: $targetOrder');
          debugPrint('🔍 Available fields in target order:');
          targetOrder.forEach((key, value) {
            debugPrint('🔍   $key: $value');
          });

          // Check if we need to update total and delivery fee
          // Group orders by delivery_id to calculate actual total
          final deliveryId = targetOrder['delivery_id']?.toString();
          if (deliveryId != null) {
            // Find all orders with same delivery_id to get the complete order
            final groupedOrders = orders
                .where((o) => o['delivery_id']?.toString() == deliveryId)
                .toList();

            if (groupedOrders.isNotEmpty) {
              // Calculate actual total from all items in this delivery
              double actualSubtotal = 0.0;
              for (var order in groupedOrders) {
                final price = (order['price'] ?? 0.0).toDouble();
                final qty = (order['qty'] ?? 1).toInt();
                actualSubtotal += price * qty;
              }

              debugPrint(
                  '🔍 Grouped ${groupedOrders.length} orders for delivery_id: $deliveryId');
              debugPrint(
                  '🔍 Calculated subtotal from grouped orders: $actualSubtotal');

              // Check if there's a delivery fee field in any of the orders
              double? foundDeliveryFee;
              for (var order in groupedOrders) {
                final fee = order['delivery_fee'] ?? order['deliveryFee'];
                if (fee != null) {
                  foundDeliveryFee = (fee is num)
                      ? fee.toDouble()
                      : (double.tryParse(fee.toString()) ?? 0.0);
                  debugPrint(
                      '🔍 Found delivery fee in order: $foundDeliveryFee');
                  if (foundDeliveryFee > 0) break;
                }
              }

              // If delivery fee not found in orders, the API doesn't return it
              // We'll need to calculate it from the actual paid amount if available
              // For now, we'll estimate it based on the difference if total_price > subtotal
              if (foundDeliveryFee == null || foundDeliveryFee <= 0) {
                debugPrint('🔍 Delivery fee not in orders API response');
                debugPrint(
                    '🔍 Note: Orders API does not return delivery fee field');
                debugPrint(
                    '🔍 Delivery fee should be passed from order confirmation page');
              }

              // If we found delivery fee, store it
              if (foundDeliveryFee != null && foundDeliveryFee > 0) {
                final feeValue = foundDeliveryFee;
                debugPrint('🔍 ✅ Storing delivery fee from API: $feeValue');
                if (mounted) {
                  setState(() {
                    _actualDeliveryFee = feeValue;
                    _actualTotalAmount = actualSubtotal + feeValue;
                  });
                }
              } else {
                debugPrint('🔍 ⚠️ Could not find delivery fee in API response');
                debugPrint(
                    '🔍 This is expected - orders API does not return delivery fee');
                debugPrint(
                    '🔍 Delivery fee should come from order confirmation page data');
              }
            }
          }

          // get delivery info from the order we found
          // note: the api response doesnt seem to have delivery address fields
          // we'll use what we have and show a message if info is missing
          final address = targetOrder['delivery_address']?.toString() ??
              targetOrder['shipping_address']?.toString() ??
              targetOrder['address']?.toString() ??
              targetOrder['addr_1']?.toString();
          final contact = targetOrder['contact_number']?.toString() ??
              targetOrder['phone']?.toString() ??
              targetOrder['user_phone']?.toString();
          final method = targetOrder['delivery_option']?.toString() ??
              targetOrder['shipping_method']?.toString() ??
              targetOrder['delivery_method']?.toString() ??
              targetOrder['shipping_type']?.toString();

          if (address != null &&
              address.isNotEmpty &&
              _deliveryAddress == 'Address not available') {
            debugPrint('🔍 Found delivery address from orders API: $address');
            setState(() {
              _deliveryAddress = address;
            });
          }

          if (contact != null &&
              contact.isNotEmpty &&
              _contactNumber == 'Contact not available') {
            debugPrint('🔍 Found contact number from orders API: $contact');
            setState(() {
              _contactNumber = contact;
            });
          }

          if (method != null &&
              method.isNotEmpty &&
              _deliveryOption == 'Standard Delivery') {
            debugPrint('🔍 Found delivery method from orders API: $method');
            setState(() {
              _deliveryOption = method;
            });
          }

          // Update order status from API so the delivery progression timeline can move
          String? apiStatus = targetOrder['status']?.toString() ??
              targetOrder['order_status']?.toString();
          if (apiStatus == null || apiStatus.isEmpty) {
            final dId = targetOrder['delivery_id']?.toString();
            if (dId != null) {
              final group = orders
                  .where((o) => o['delivery_id']?.toString() == dId)
                  .toList();
              for (final o in group) {
                final s =
                    o['status']?.toString() ?? o['order_status']?.toString();
                if (s != null && s.isNotEmpty) {
                  apiStatus = s;
                  break;
                }
              }
            }
          }
          if (apiStatus != null && apiStatus.isNotEmpty && mounted) {
            setState(() {
              _orderStatus = apiStatus;
            });
            debugPrint('🔍 Updated order status from API: $apiStatus');
          }

          // if we still dont have delivery info, show a message
          if (_deliveryAddress == 'Address not available' &&
              _contactNumber == 'Contact not available') {
            debugPrint(
                '🔍 No delivery info found in orders API - this appears to be a limitation of the current API');
          }
        } else {
          debugPrint(
              '🔍 Target order not found in list (direct API already tried)');
        }
      } else {
        debugPrint('🔍 Orders API did not return success: ${result['status']}');
      }
    } catch (e) {
      debugPrint('🔍 Error fetching order details from API: $e');
    }
  }

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(url);
  }

  // Helper method to get order items - handles both single and multiple items
  List<Map<String, dynamic>> getOrderItems() {
    final orderDetails = widget.orderDetails;

    // Check if this is a multi-item order
    if (orderDetails['order_items'] != null &&
        orderDetails['order_items'] is List) {
      final items = orderDetails['order_items'] as List;
      return items.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).toList();
    }

    // single item order, just make one item map
    return [
      {
        'product_name': orderDetails['product_name'] ?? 'Unknown Product',
        'product_img': orderDetails['product_img'] ?? '',
        'qty': orderDetails['qty'] ?? 1,
        'price': orderDetails['price'] ?? 0.0,
        'batch_no': orderDetails['batch_no'] ?? '',
      }
    ];
  }

  // add up the total quantity of all items
  int getTotalQuantity() {
    return getOrderItems()
        .fold(0, (sum, item) => sum + (item['qty'] ?? 1) as int);
  }

  // Get total amount - use total_price from order if available (includes delivery fee),
  // otherwise calculate from items and add delivery fee
  double getTotalAmount() {
    // Calculate subtotal from items first
    final subtotal = getOrderItems().fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0.0).toDouble();
      final qty = item['qty'] ?? 1;
      return sum + (price * qty);
    });

    // Get discount if any
    final discountValue = widget.orderDetails['discount'] ??
        widget.orderDetails['discount_amount'];
    final discount = discountValue != null
        ? ((discountValue is num)
            ? discountValue.toDouble()
            : (double.tryParse(discountValue.toString()) ?? 0.0))
        : 0.0;

    // Get delivery fee from order details
    final deliveryFeeValue = widget.orderDetails['delivery_fee'] ??
        widget.orderDetails['deliveryFee'] ??
        widget.orderDetails['delivery_fee_amount'] ??
        widget.orderDetails['shipping_fee'] ??
        widget.orderDetails['shippingFee'];
    double deliveryFee = 0.0;
    if (deliveryFeeValue != null) {
      deliveryFee = (deliveryFeeValue is num)
          ? deliveryFeeValue.toDouble()
          : (double.tryParse(deliveryFeeValue.toString()) ?? 0.0);
    }

    // Try to use total_price/total_amount/amount from order details
    final orderTotalPrice = widget.orderDetails['total_price'] ??
        widget.orderDetails['total_amount'] ??
        widget.orderDetails['amount'];

    if (orderTotalPrice != null) {
      final totalFromOrder = (orderTotalPrice is num)
          ? orderTotalPrice.toDouble()
          : (double.tryParse(orderTotalPrice.toString()) ?? 0.0);

      if (totalFromOrder > 0) {
        // Check if totalFromOrder equals subtotal exactly (within 0.01 tolerance)
        // This means the API only returned subtotal, not the total with delivery fee
        final isSubtotalOnly = (totalFromOrder - subtotal).abs() < 0.01;

        if (isSubtotalOnly && deliveryFee <= 0.01) {
          // total_price is just subtotal, and no delivery fee in order details
          // Check if we fetched actual total/delivery fee from API
          if (_actualTotalAmount != null && _actualTotalAmount! > subtotal) {
            debugPrint(
                '🔍 getTotalAmount: Using actual total fetched from API: $_actualTotalAmount');
            return _actualTotalAmount!;
          }
          if (_actualDeliveryFee != null && _actualDeliveryFee! > 0) {
            final calculatedTotal = subtotal + _actualDeliveryFee! - discount;
            debugPrint(
                '🔍 getTotalAmount: Using delivery fee fetched from API: $_actualDeliveryFee, total: $calculatedTotal');
            return calculatedTotal;
          }

          // total_price is just subtotal, and no delivery fee in order details
          // This means delivery fee is missing from API response
          debugPrint(
              '🔍 getTotalAmount: ⚠️ total_price ($totalFromOrder) equals subtotal ($subtotal) - delivery fee missing from API');
          debugPrint(
              '🔍 getTotalAmount: Returning subtotal only (delivery fee not available): $subtotal');
          return subtotal;
        } else if (isSubtotalOnly && deliveryFee > 0.01) {
          // total_price is subtotal, but we have delivery fee from order details
          final correctedTotal = totalFromOrder + deliveryFee - discount;
          debugPrint(
              '🔍 getTotalAmount: total_price is subtotal only. Adding delivery fee: $totalFromOrder + $deliveryFee - $discount = $correctedTotal');
          return correctedTotal;
        } else if (totalFromOrder > subtotal + 0.01) {
          // totalFromOrder is greater than subtotal, so it likely includes delivery fee
          debugPrint(
              '🔍 getTotalAmount: Using total_price/total_amount/amount (includes delivery): $totalFromOrder');
          return totalFromOrder;
        } else {
          // Use totalFromOrder as is (might be less than subtotal due to discount)
          debugPrint(
              '🔍 getTotalAmount: Using total_price/total_amount/amount: $totalFromOrder');
          return totalFromOrder;
        }
      }
    }

    // Fallback: calculate total from subtotal + delivery fee - discount
    final calculatedTotal = subtotal + deliveryFee - discount;
    debugPrint(
        '🔍 getTotalAmount: Calculated total: subtotal $subtotal + deliveryFee $deliveryFee - discount $discount = $calculatedTotal');
    return calculatedTotal;
  }

  // Helper method to format quantity text
  String formatQuantityText(int quantity) {
    return quantity == 1 ? '1 item' : '$quantity items';
  }

  @override
  Widget build(BuildContext context) {
    try {
      debugPrint('🔍 OrderTrackingPage build method called');
      debugPrint('🔍 Order details: ${widget.orderDetails}');

      final orderDate =
          DateTime.tryParse(widget.orderDetails['created_at'] ?? '');
      final status =
          _orderStatus ?? widget.orderDetails['status'] ?? 'Processing';
      final orderItems = getOrderItems();
      final totalQuantity = getTotalQuantity();
      final totalAmount = getTotalAmount();
      final orderNumber = widget.orderDetails['order_number']?.toString() ??
          widget.orderDetails['delivery_id']?.toString() ??
          widget.orderDetails['transaction_id']?.toString() ??
          widget.orderDetails['order_id']?.toString() ??
          widget.orderDetails['id']?.toString() ??
          'N/A';
      final isPickup = _isPickupOrder();

      debugPrint('🔍 Order date: $orderDate');
      debugPrint('🔍 Status: $status');
      debugPrint('🔍 Total quantity: $totalQuantity');
      debugPrint('🔍 Total amount: $totalAmount');

      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: _isLoading
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  EclExpandableSliverAppBar(
                    toolbarTitle: _sliverHeaderOrderLabel(),
                    heroTitle: _sliverHeaderOrderLabel(),
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AppBackButton(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        iconColor: Colors.white,
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        },
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CartIconButton(
                            iconColor: Colors.white,
                            iconSize: 22,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green.shade700),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Fetching your order…',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hang tight',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: _loadDeliveryInfo,
                color: Colors.green.shade700,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    EclExpandableSliverAppBar(
                      toolbarTitle: _sliverHeaderOrderLabel(),
                      heroTitle: _sliverHeaderOrderLabel(),
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AppBackButton(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          iconColor: Colors.white,
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/', (route) => false);
                            }
                          },
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CartIconButton(
                              iconColor: Colors.white,
                              iconSize: 22,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildModernHeader(
                              orderNumber, status, orderDate, isPickup),
                          const SizedBox(height: 16),
                          _buildOrderItemsCard(
                              orderItems, totalQuantity, totalAmount),
                          const SizedBox(height: 16),
                          _buildStatusTimelineCard(status, isPickup),
                          const SizedBox(height: 16),
                          _buildDeliveryDetailsCard(isPickup: isPickup),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      );
    } catch (e) {
      debugPrint('🔍 Error in OrderTrackingPage build: $e');
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            EclExpandableSliverAppBar(
              toolbarTitle: _sliverHeaderOrderLabel(),
              heroTitle: _sliverHeaderOrderLabel(),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error loading order tracking',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Error: $e',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
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

  Widget _buildModernHeader(
      String orderNumber, String status, DateTime? orderDate, bool isPickup) {
    // derive a primary color/icon for the current status so the header feels more alive
    final lowerStatus = status.toLowerCase().trim();
    Color accentColor;
    IconData accentIcon;
    String friendlyStatus;
    if (lowerStatus.contains('delivered') || lowerStatus == 'completed') {
      accentColor = Colors.green.shade600;
      accentIcon = Icons.check_circle_rounded;
      friendlyStatus = 'Delivered';
    } else if (lowerStatus.contains('out for delivery') ||
        lowerStatus.contains('out_for_delivery') ||
        lowerStatus.contains('shipped') ||
        lowerStatus == 'shipped' ||
        lowerStatus.contains('out for')) {
      accentColor = Colors.blue.shade600;
      accentIcon = Icons.delivery_dining_rounded;
      friendlyStatus = 'Out for delivery';
    } else if (lowerStatus.contains('paid') ||
        lowerStatus.contains('confirm') ||
        lowerStatus == 'processing' ||
        lowerStatus == 'payment received' ||
        lowerStatus == 'payment verified' ||
        lowerStatus == 'pending confirmation') {
      accentColor = Colors.orange.shade600;
      accentIcon = Icons.verified_rounded;
      friendlyStatus = 'Confirmed';
    } else if (lowerStatus == 'order placed' || lowerStatus == 'pending') {
      accentColor = Colors.grey.shade700;
      accentIcon = Icons.receipt_long_rounded;
      friendlyStatus = 'Order placed';
    } else {
      accentColor = Colors.grey.shade700;
      accentIcon = Icons.info_rounded;
      friendlyStatus = status.isNotEmpty ? status : 'Pending';
    }

    if (isPickup) {
      if (friendlyStatus == 'Out for delivery') {
        friendlyStatus = 'Ready for Pickup';
        accentIcon = Icons.store_mall_directory_rounded;
        accentColor = Colors.teal.shade600;
      } else if (friendlyStatus == 'Delivered') {
        friendlyStatus = 'Picked up';
        accentIcon = Icons.shopping_bag_rounded;
      }
    }

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(_kTrackRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kTrackRadius),
          border: Border.all(
            color: Colors.grey.shade200.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kTrackRadius),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isPickup
                                  ? Icons.storefront_outlined
                                  : Icons.local_shipping_outlined,
                              size: 15,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPickup ? 'Pickup order' : 'Delivery order',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const Spacer(),
                            _buildStatusBadge(status, isPickup: isPickup),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              accentIcon,
                              size: 26,
                              color: accentColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                friendlyStatus,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade900,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (orderDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('EEE, MMM d · h:mm a').format(orderDate),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Order ID',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          orderNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                            letterSpacing: 0.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool isPickup = false}) {
    Color statusColor;
    String statusText;

    final s = status.toLowerCase().trim();
    // Check "out for delivery" / "shipped" BEFORE "delivered" (since "out for delivery" contains "deliver")
    if (s.contains('out for delivery') ||
        s.contains('out_for_delivery') ||
        s.contains('shipped') ||
        s == 'shipped' ||
        s.contains('out for')) {
      statusColor = Colors.blue.shade600;
      statusText = 'Out for Delivery';
    } else if (s.contains('delivered') ||
        s == 'delivered' ||
        s == 'completed') {
      statusColor = Colors.green.shade600;
      statusText = 'Delivered';
    } else if (s.contains('ship')) {
      statusColor = Colors.blue.shade600;
      statusText = 'Out for Delivery';
    } else if (s.contains('paid') ||
        s.contains('confirm') ||
        s == 'processing' ||
        s == 'payment received' ||
        s == 'payment verified' ||
        s == 'pending confirmation') {
      statusColor = Colors.orange.shade600;
      statusText = 'Confirmed';
    } else if (s == 'order placed' || s == 'pending') {
      statusColor = Colors.grey.shade600;
      statusText = 'Order Placed';
    } else {
      statusColor = Colors.grey.shade600;
      statusText = status.isNotEmpty ? status : 'Pending';
    }

    if (isPickup) {
      if (statusText == 'Out for Delivery') {
        statusText = 'Ready for Pickup';
      } else if (statusText == 'Delivered') {
        statusText = 'Picked up';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: statusColor,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  Widget _buildStatusTimelineCard(String currentStatus, bool isPickup) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(_kTrackRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kTrackRadius),
          border:
              Border.all(color: Colors.grey.shade200.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isPickup ? Colors.teal.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPickup ? Icons.storefront_rounded : Icons.route_rounded,
                    size: 20,
                    color:
                        isPickup ? Colors.teal.shade800 : Colors.green.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPickup ? 'Pickup progress' : 'Delivery progress',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        isPickup
                            ? 'From order to collection'
                            : 'Step-by-step updates',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 28, color: Colors.grey.shade100),
            _buildModernStatusTimeline(currentStatus, isPickup: isPickup),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard(List<Map<String, dynamic>> orderItems,
      int totalQuantity, double totalAmount) {
    // Calculate subtotal from items
    final subtotal = orderItems.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0.0).toDouble();
      final qty = item['qty'] ?? 1;
      return sum + (price * qty);
    });

    // Get discount first (needed for delivery fee calculation)
    final discountValue = widget.orderDetails['discount'] ??
        widget.orderDetails['discount_amount'];
    final discount = discountValue != null
        ? ((discountValue is num)
            ? discountValue.toDouble()
            : (double.tryParse(discountValue.toString()) ?? 0.0))
        : 0.0;

    // Get delivery fee from order details - prioritize delivery_fee and deliveryFee
    // These are set when navigating from order confirmation page
    final deliveryFeeValue = widget.orderDetails['delivery_fee'] ??
        widget.orderDetails['deliveryFee'];

    double deliveryFee = 0.0;
    if (deliveryFeeValue != null) {
      deliveryFee = (deliveryFeeValue is num)
          ? deliveryFeeValue.toDouble()
          : (double.tryParse(deliveryFeeValue.toString()) ?? 0.0);
    }

    // Debug logging
    debugPrint('🔍 ===== Delivery Fee Calculation =====');
    debugPrint('🔍   totalAmount: $totalAmount');
    debugPrint('🔍   subtotal: $subtotal');
    debugPrint('🔍   discount: $discount');
    debugPrint('🔍   deliveryFeeValue from order: $deliveryFeeValue');
    debugPrint('🔍   deliveryFee (from order): $deliveryFee');

    // Use stored delivery fee if available (stored when order was placed)
    if (deliveryFee <= 0.01 &&
        _actualDeliveryFee != null &&
        _actualDeliveryFee! > 0.01) {
      deliveryFee = _actualDeliveryFee!;
      debugPrint('🔍   ✅ Using stored delivery fee: $deliveryFee');
    }

    // Calculate delivery fee from difference: total = subtotal + deliveryFee - discount
    // So: deliveryFee = total - subtotal + discount
    // This is a fallback when delivery fee is not explicitly provided
    if (deliveryFee <= 0.01) {
      final calculatedFeeFromDifference = totalAmount - subtotal + discount;
      if (calculatedFeeFromDifference > 0.01) {
        deliveryFee = calculatedFeeFromDifference;
        debugPrint(
            '🔍   ✅ Using calculated deliveryFee from difference: $deliveryFee');
      }
    }

    debugPrint('🔍   ===== Final deliveryFee: $deliveryFee =====');
    debugPrint('🔍   Will show delivery fee: ${deliveryFee > 0.01}');

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(_kTrackRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kTrackRadius),
          border:
              Border.all(color: Colors.grey.shade200.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items & payment',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        'What you ordered',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalQuantity item${totalQuantity == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'GHS ${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...orderItems.map((item) => _buildModernOrderItemRow(item)),
            const Divider(height: 14),
            // Price Breakdown
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'GHS ${subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            // Delivery Fee - always show if there's a difference between total and subtotal
            Builder(
              builder: (context) {
                // Use the deliveryFee calculated above, or calculate from difference
                double finalDeliveryFee = deliveryFee;

                // If delivery fee is 0 or very small, calculate from difference
                // Formula: total = subtotal + deliveryFee - discount
                // So: deliveryFee = total - subtotal + discount
                if (finalDeliveryFee <= 0.01) {
                  final calculatedFee = totalAmount - subtotal + discount;
                  if (calculatedFee > 0.01) {
                    finalDeliveryFee = calculatedFee;
                  }
                }

                debugPrint(
                    '🔍 Display Builder: finalDeliveryFee=$finalDeliveryFee, totalAmount=$totalAmount, subtotal=$subtotal, discount=$discount');

                // Always show if there's a meaningful delivery fee
                if (finalDeliveryFee > 0.01) {
                  debugPrint(
                      '🔍 Display: ✅ SHOWING delivery fee: GHS ${finalDeliveryFee.toStringAsFixed(2)}');
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery Fee',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'GHS ${finalDeliveryFee.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  debugPrint('🔍 Display: ❌ NOT showing delivery fee');
                  debugPrint('🔍   - finalDeliveryFee: $finalDeliveryFee');
                  debugPrint('🔍   - totalAmount: $totalAmount');
                  debugPrint('🔍   - subtotal: $subtotal');
                  debugPrint('🔍   - discount: $discount');
                  debugPrint(
                      '🔍   - calculated difference: ${totalAmount - subtotal + discount}');
                }
                return const SizedBox.shrink();
              },
            ),
            // Discount (if any)
            if (discount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    '-GHS ${discount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 12),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  'GHS ${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernOrderItemRow(Map<String, dynamic> item) {
    final productName = item['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(item['product_img']);
    final qty = item['qty'] ?? 1;
    final price = (item['price'] ?? 0.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              productImg,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.image_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty $qty',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'GHS ${price.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusTimeline(String currentStatus,
      {required bool isPickup}) {
    final List<Map<String, Object>> statuses = isPickup
        ? [
            {
              'title': 'Order Placed',
              'status': 'pending',
              'icon': Icons.shopping_cart_rounded,
            },
            {'title': 'Paid', 'status': 'paid', 'icon': Icons.payment_rounded},
            {
              'title': 'Pending Confirmation',
              'status': 'pending_confirmation',
              'icon': Icons.hourglass_empty_rounded,
            },
            {
              'title': 'Order Confirmed',
              'status': 'confirmed',
              'icon': Icons.check_circle_outline_rounded,
            },
            {
              'title': 'Ready for Pickup',
              'status': 'shipped',
              'icon': Icons.store_mall_directory_rounded,
            },
            {
              'title': 'Picked up',
              'status': 'delivered',
              'icon': Icons.shopping_bag_rounded,
            },
          ]
        : [
            {
              'title': 'Order Placed',
              'status': 'pending',
              'icon': Icons.shopping_cart_rounded,
            },
            {'title': 'Paid', 'status': 'paid', 'icon': Icons.payment_rounded},
            {
              'title': 'Pending Confirmation',
              'status': 'pending_confirmation',
              'icon': Icons.hourglass_empty_rounded,
            },
            {
              'title': 'Order Confirmed',
              'status': 'confirmed',
              'icon': Icons.check_circle_outline_rounded,
            },
            {
              'title': 'Out for Delivery',
              'status': 'shipped',
              'icon': Icons.delivery_dining_rounded,
            },
            {
              'title': 'Delivered',
              'status': 'delivered',
              'icon': Icons.check_circle_rounded,
            },
          ];

    final normalizedStatus = currentStatus.toLowerCase().trim();
    // Map API statuses to timeline steps
    String timelineStatus;
    if (normalizedStatus == 'order placed' || normalizedStatus == 'pending') {
      timelineStatus = 'pending';
    } else if (normalizedStatus.contains('paid') &&
        !normalizedStatus.contains('pending')) {
      timelineStatus = 'paid';
    } else if (normalizedStatus == 'pending confirmation' ||
        normalizedStatus.contains('pending_confirmation') ||
        normalizedStatus == 'payment received' ||
        normalizedStatus == 'payment verified') {
      timelineStatus = 'pending_confirmation';
    } else if (normalizedStatus.contains('confirmed') ||
        normalizedStatus.contains('confirm')) {
      timelineStatus = 'confirmed';
    } else if (normalizedStatus == 'processing' ||
        normalizedStatus.contains('preparing') ||
        normalizedStatus.contains('packing')) {
      timelineStatus = 'confirmed';
    } else if (normalizedStatus.contains('out for delivery') ||
        normalizedStatus.contains('out_for_delivery') ||
        normalizedStatus.contains('shipped') ||
        normalizedStatus == 'shipped' ||
        normalizedStatus.contains('out for')) {
      timelineStatus = 'shipped';
    } else if (normalizedStatus.contains('ship')) {
      timelineStatus = 'shipped';
    } else if (normalizedStatus.contains('delivered') ||
        normalizedStatus == 'delivered' ||
        normalizedStatus == 'completed') {
      timelineStatus = 'delivered';
    } else {
      timelineStatus = normalizedStatus;
    }

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final statusStr = status['status'] as String;
        final isCompleted = _isStatusCompleted(statusStr, normalizedStatus);
        final isCurrent = statusStr == timelineStatus;
        final icon = status['icon'] as IconData;
        final displayTitle = status['title'] as String;

        final lineDone = isCompleted;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade600
                          : isCurrent
                              ? Colors.blue.shade600
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent && !isCompleted
                            ? Colors.blue.shade200
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (isCompleted || isCurrent)
                          BoxShadow(
                            color: (isCompleted
                                    ? Colors.green.shade600
                                    : Colors.blue.shade600)
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: isCompleted || isCurrent
                          ? Colors.white
                          : Colors.grey.shade500,
                      size: 17,
                    ),
                  ),
                  if (index < statuses.length - 1)
                    Container(
                      width: 3,
                      height: 22,
                      margin: const EdgeInsets.only(top: 4, bottom: 2),
                      decoration: BoxDecoration(
                        color: lineDone
                            ? Colors.green.shade300
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : isCompleted
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                          color: isCurrent
                              ? Colors.blue.shade800
                              : isCompleted
                                  ? Colors.green.shade800
                                  : Colors.grey.shade500,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Now',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  bool _isStatusCompleted(String status, String currentStatus) {
    final statusOrder = [
      'pending',
      'paid',
      'pending_confirmation',
      'confirmed',
      'shipped',
      'delivered'
    ];

    // Normalize status
    final normalizedCurrentStatus = currentStatus.toLowerCase().trim();
    String normalizedStatus;
    if (normalizedCurrentStatus == 'order placed' ||
        normalizedCurrentStatus == 'pending') {
      normalizedStatus = 'pending';
    } else if (normalizedCurrentStatus.contains('paid') &&
        !normalizedCurrentStatus.contains('pending')) {
      normalizedStatus = 'paid';
    } else if (normalizedCurrentStatus == 'pending confirmation' ||
        normalizedCurrentStatus.contains('pending_confirmation') ||
        normalizedCurrentStatus == 'payment received' ||
        normalizedCurrentStatus == 'payment verified') {
      normalizedStatus = 'pending_confirmation';
    } else if (normalizedCurrentStatus.contains('confirmed') ||
        normalizedCurrentStatus.contains('confirm')) {
      normalizedStatus = 'confirmed';
    } else if (normalizedCurrentStatus == 'processing' ||
        normalizedCurrentStatus.contains('preparing') ||
        normalizedCurrentStatus.contains('packing')) {
      normalizedStatus = 'confirmed';
    } else if (normalizedCurrentStatus.contains('out for delivery') ||
        normalizedCurrentStatus.contains('out_for_delivery') ||
        normalizedCurrentStatus.contains('shipped') ||
        normalizedCurrentStatus == 'shipped' ||
        normalizedCurrentStatus.contains('out for')) {
      normalizedStatus = 'shipped';
    } else if (normalizedCurrentStatus.contains('ship')) {
      normalizedStatus = 'shipped';
    } else if (normalizedCurrentStatus.contains('delivered') ||
        normalizedCurrentStatus == 'delivered' ||
        normalizedCurrentStatus == 'completed') {
      normalizedStatus = 'delivered';
    } else {
      normalizedStatus = normalizedCurrentStatus;
    }

    final currentIndex = statusOrder.indexOf(normalizedStatus);
    final statusIndex = statusOrder.indexOf(status);

    // If current status is not in the list, treat it as 'pending'
    if (currentIndex == -1) {
      return status == 'pending';
    }

    return statusIndex <= currentIndex;
  }

  Widget _buildDeliveryDetailsCard({required bool isPickup}) {
    Widget detailBlock({
      required IconData icon,
      required String title,
      required String body,
      required Color tint,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 20, color: Color.lerp(tint, Colors.black, 0.15)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade900,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(_kTrackRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kTrackRadius),
          border:
              Border.all(color: Colors.grey.shade200.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isPickup ? Colors.teal.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPickup
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
                    size: 20,
                    color: isPickup
                        ? Colors.teal.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPickup ? 'Pickup details' : 'Delivery details',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        isPickup
                            ? 'Where to collect your order'
                            : 'Where we are bringing your order',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            detailBlock(
              icon: Icons.location_on_outlined,
              title: isPickup ? 'Pickup location' : 'Address',
              body: isPickup
                  ? _pickupLocationSummary()
                  : (_deliveryAddress ?? 'Not available'),
              tint: Colors.green.shade700,
            ),
            const SizedBox(height: 6),
            Divider(height: 28, color: Colors.grey.shade100),
            detailBlock(
              icon: Icons.phone_outlined,
              title: 'Contact',
              body: _contactNumber ?? 'Not available',
              tint: Colors.blue.shade700,
            ),
            const SizedBox(height: 6),
            Divider(height: 28, color: Colors.grey.shade100),
            detailBlock(
              icon: isPickup
                  ? Icons.store_mall_directory_outlined
                  : Icons.schedule_send_outlined,
              title: 'Method',
              body: isPickup
                  ? 'Store pickup'
                  : (_deliveryOption ?? 'Standard delivery'),
              tint: Colors.deepPurple.shade700,
            ),
          ],
        ),
      ),
    );
  }
}
