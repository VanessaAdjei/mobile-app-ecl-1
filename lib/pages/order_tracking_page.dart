// pages/order_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/cart_icon_button.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/delivery_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
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
  String? _deliveryAddress;
  String? _contactNumber;
  String? _deliveryOption;
  bool _isLoading = true;
  double? _actualTotalAmount; // Store actual total fetched from API if needed
  double? _actualDeliveryFee; // Store actual delivery fee fetched from API if needed
  /// Current order status for timeline; updated from API so progression can move.
  String? _orderStatus;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 OrderTrackingPage initState called');
    debugPrint('🔍 Order details in initState: ${widget.orderDetails}');
    debugPrint('🔍 All order details keys: ${widget.orderDetails.keys.toList()}');
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
      debugPrint('🔍 Delivery fee missing - trying to retrieve from stored data...');
      _loadStoredDeliveryFee();
    }
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
        _orderStatus = widget.orderDetails['status']?.toString() ?? 'Processing';
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
        _orderStatus = widget.orderDetails['status']?.toString() ?? 'Processing';
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
            final orderNumericPart = key.replaceFirst('order_delivery_fee_ORDER_', '');
            // Try matching with different lengths (ECL might have shorter timestamp)
            // Match if ORDER_ timestamp starts with ECL timestamp (or vice versa)
            final minLength = eclNumericPart.length < orderNumericPart.length 
                ? eclNumericPart.length 
                : orderNumericPart.length;
            if (minLength >= 10) {
              // Try matching first 10 digits (common timestamp length)
              final eclPrefix = eclNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              final orderPrefix = orderNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              if (eclPrefix == orderPrefix) {
                deliveryFeeKey = key;
                storedDeliveryFee = prefs.getDouble(key);
                debugPrint('🔍 Found delivery fee with ORDER_ prefix: $key (matched by timestamp prefix)');
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
            final eclNumericPart = key.replaceFirst('order_delivery_fee_ECL', '');
            // Try matching with different lengths
            final minLength = eclNumericPart.length < orderNumericPart.length 
                ? eclNumericPart.length 
                : orderNumericPart.length;
            if (minLength >= 10) {
              // Try matching first 10 digits (common timestamp length)
              final eclPrefix = eclNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              final orderPrefix = orderNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              if (eclPrefix == orderPrefix) {
                deliveryFeeKey = key;
                storedDeliveryFee = prefs.getDouble(key);
                debugPrint('🔍 Found delivery fee with ECL format: $key (matched by timestamp prefix)');
                break;
              }
            }
          }
        }
      }
      
      if (storedDeliveryFee != null && storedDeliveryFee > 0) {
        debugPrint('🔍 ✅ Found stored delivery fee: $storedDeliveryFee for order $transactionId');
        // Also get the total if available
        if (storedTotal == null) {
          totalKey = deliveryFeeKey.replaceFirst('order_delivery_fee_', 'order_total_');
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

      // get auth token using auth service
      final token = await AuthService.getToken();

      if (token == null) {
        debugPrint('🔍 No auth token available for API call');
        debugPrint('🔍 User might not be logged in or token expired');
        return;
      }

      debugPrint(
          '🔍 Auth token retrieved successfully: ${token.substring(0, 20)}...');

      // get all orders and find the one we need
      try {
        debugPrint('🔍 Trying to get all orders to find delivery info...');
        final ordersResponse = await http.get(
          Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/orders'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (ordersResponse.statusCode == 200) {
          final ordersData = json.decode(ordersResponse.body);
          debugPrint(
              '🔍 Orders API response received, looking for order $orderId');
          debugPrint('🔍 Complete API response: $ordersData');

          // check if api says it worked
          final apiStatus = ordersData['status']?.toString();
          if (apiStatus != 'success') {
            debugPrint('🔍 API response status is not success: $apiStatus');
            return;
          }

          // use 'data' field instead of 'orders' (thats how the api actually works)
          final orders = ordersData['data'] ?? [];
          debugPrint('🔍 Total orders received: ${orders.length}');

          // check if orders are in a different field (fallback)
          if (orders.isEmpty) {
            debugPrint(
                '🔍 No orders in "data" field, checking other possible fields...');
            final possibleFields = ['orders', 'items', 'results', 'list'];
            for (final field in possibleFields) {
              final fieldData = ordersData[field];
              if (fieldData != null) {
                debugPrint('🔍 Found data in "$field" field: $fieldData');
                if (fieldData is List) {
                  debugPrint('🔍 "$field" contains ${fieldData.length} items');
                }
              }
            }
          }

          // print what we're looking for
          debugPrint('🔍 Looking for order with:');
          debugPrint('🔍   - orderId: $orderId');
          debugPrint('🔍   - orderNumber: $orderNumber');
          debugPrint(
              '🔍   - notification delivery_id: ${widget.orderDetails['delivery_id']}');

          // print first few orders so we can see the structure
          if (orders.isNotEmpty) {
            debugPrint('🔍 Sample orders from API:');
            for (int i = 0; i < orders.length && i < 5; i++) {
              final order = orders[i];
              debugPrint(
                  '🔍 Order ${i + 1}: ID=${order['id']}, Delivery ID=${order['delivery_id']}, User ID=${order['user_id']}');
            }
          }

          // try different ways to find the order
          Map<String, dynamic>? targetOrder;

          // first try matching by delivery_id (most reliable for notifications)
          final notificationDeliveryId =
              widget.orderDetails['delivery_id']?.toString() ??
              widget.orderDetails['transaction_id']?.toString();
          if (notificationDeliveryId != null &&
              notificationDeliveryId.isNotEmpty) {
            debugPrint(
                '🔍 Trying to match by delivery_id/transaction_id: $notificationDeliveryId');
            try {
              targetOrder = orders.firstWhere(
                (order) => order['delivery_id'] == notificationDeliveryId,
                orElse: () => null,
              );
              if (targetOrder != null) {
                debugPrint(
                    '🔍 Found order by delivery_id: ${targetOrder['delivery_id']}');
              }
            } catch (e) {
              debugPrint('🔍 Error finding order by delivery_id: $e');
            }
          }

          // if that didnt work, try matching by order number
          if (targetOrder == null &&
              orderNumber != null &&
              orderNumber != notificationDeliveryId) {
            debugPrint('🔍 Trying to match by order number: $orderNumber');
            targetOrder = orders.firstWhere(
              (order) => order['delivery_id'] == orderNumber,
              orElse: () => null,
            );
            if (targetOrder != null) {
              debugPrint(
                  '🔍 Found order by order number: ${targetOrder['delivery_id']}');
            }
          }

          // if that didnt work, try matching by numeric id (extract from ORDER_ prefix) - less reliable
          if (targetOrder == null &&
              orderId != null &&
              orderId.startsWith('ORDER_')) {
            final numericId = orderId.replaceFirst('ORDER_', '');
            debugPrint('🔍 Trying to match by numeric ID: $numericId');
            try {
              final numericIdInt = int.tryParse(numericId);
              if (numericIdInt != null) {
                targetOrder = orders.firstWhere(
                  (order) => order['id'] == numericIdInt,
                  orElse: () => null,
                );
                if (targetOrder != null) {
                  debugPrint(
                      '🔍 Found order by numeric ID: ${targetOrder['id']}');
                }
              }
            } catch (e) {
              debugPrint('🔍 Error parsing numeric ID: $e');
            }
          }

          // last try: match by order id as string (fallback)
          if (targetOrder == null && orderId != null) {
            debugPrint('🔍 Trying to match by order ID string: $orderId');
            targetOrder = orders.firstWhere(
              (order) =>
                  order['id'].toString() == orderId ||
                  order['delivery_id'] == orderId,
              orElse: () => null,
            );
            if (targetOrder != null) {
              debugPrint('🔍 Found order by ID string: ${targetOrder['id']}');
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
              final groupedOrders = orders.where((o) => 
                o['delivery_id']?.toString() == deliveryId
              ).toList();
              
              if (groupedOrders.isNotEmpty) {
                // Calculate actual total from all items in this delivery
                double actualSubtotal = 0.0;
                for (var order in groupedOrders) {
                  final price = (order['price'] ?? 0.0).toDouble();
                  final qty = (order['qty'] ?? 1).toInt();
                  actualSubtotal += price * qty;
                }
                
                debugPrint('🔍 Grouped ${groupedOrders.length} orders for delivery_id: $deliveryId');
                debugPrint('🔍 Calculated subtotal from grouped orders: $actualSubtotal');
                
                // Check if there's a delivery fee field in any of the orders
                double? foundDeliveryFee;
                for (var order in groupedOrders) {
                  final fee = order['delivery_fee'] ?? order['deliveryFee'];
                  if (fee != null) {
                    foundDeliveryFee = (fee is num) ? fee.toDouble() : 
                        (double.tryParse(fee.toString()) ?? 0.0);
                    debugPrint('🔍 Found delivery fee in order: $foundDeliveryFee');
                    if (foundDeliveryFee > 0) break;
                  }
                }
                
                // If delivery fee not found in orders, the API doesn't return it
                // We'll need to calculate it from the actual paid amount if available
                // For now, we'll estimate it based on the difference if total_price > subtotal
                if (foundDeliveryFee == null || foundDeliveryFee <= 0) {
                  debugPrint('🔍 Delivery fee not in orders API response');
                  debugPrint('🔍 Note: Orders API does not return delivery fee field');
                  debugPrint('🔍 Delivery fee should be passed from order confirmation page');
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
                  debugPrint('🔍 This is expected - orders API does not return delivery fee');
                  debugPrint('🔍 Delivery fee should come from order confirmation page data');
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
            final apiStatus = targetOrder['status']?.toString();
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
            debugPrint('🔍 Target order not found using any matching strategy');
            debugPrint('🔍 Available order IDs in response:');
            for (int i = 0; i < orders.length && i < 5; i++) {
              final order = orders[i];
              debugPrint(
                  '🔍 Order ${i + 1}: ID=${order['id']}, Number=${order['order_number']}');
            }
          }
        } else {
          debugPrint(
              '🔍 Orders API returned status: ${ordersResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('🔍 Error calling orders API: $e');
      }
    } catch (e) {
      debugPrint('🔍 Error fetching order details from API: $e');
    }
  }

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
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
            debugPrint('🔍 getTotalAmount: Using actual total fetched from API: $_actualTotalAmount');
            return _actualTotalAmount!;
          }
          if (_actualDeliveryFee != null && _actualDeliveryFee! > 0) {
            final calculatedTotal = subtotal + _actualDeliveryFee! - discount;
            debugPrint('🔍 getTotalAmount: Using delivery fee fetched from API: $_actualDeliveryFee, total: $calculatedTotal');
            return calculatedTotal;
          }
          
          // total_price is just subtotal, and no delivery fee in order details
          // This means delivery fee is missing from API response
          debugPrint('🔍 getTotalAmount: ⚠️ total_price ($totalFromOrder) equals subtotal ($subtotal) - delivery fee missing from API');
          debugPrint('🔍 getTotalAmount: Returning subtotal only (delivery fee not available): $subtotal');
          return subtotal;
        } else if (isSubtotalOnly && deliveryFee > 0.01) {
          // total_price is subtotal, but we have delivery fee from order details
          final correctedTotal = totalFromOrder + deliveryFee - discount;
          debugPrint('🔍 getTotalAmount: total_price is subtotal only. Adding delivery fee: $totalFromOrder + $deliveryFee - $discount = $correctedTotal');
          return correctedTotal;
        } else if (totalFromOrder > subtotal + 0.01) {
          // totalFromOrder is greater than subtotal, so it likely includes delivery fee
          debugPrint('🔍 getTotalAmount: Using total_price/total_amount/amount (includes delivery): $totalFromOrder');
          return totalFromOrder;
        } else {
          // Use totalFromOrder as is (might be less than subtotal due to discount)
          debugPrint('🔍 getTotalAmount: Using total_price/total_amount/amount: $totalFromOrder');
          return totalFromOrder;
        }
      }
    }
    
    // Fallback: calculate total from subtotal + delivery fee - discount
    final calculatedTotal = subtotal + deliveryFee - discount;
    debugPrint('🔍 getTotalAmount: Calculated total: subtotal $subtotal + deliveryFee $deliveryFee - discount $discount = $calculatedTotal');
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
      final status = _orderStatus ?? widget.orderDetails['status'] ?? 'Processing';
      final orderItems = getOrderItems();
      final totalQuantity = getTotalQuantity();
      final totalAmount = getTotalAmount();
      final orderNumber = widget.orderDetails['order_number']?.toString() ??
          widget.orderDetails['delivery_id']?.toString() ??
          widget.orderDetails['transaction_id']?.toString() ??
          widget.orderDetails['order_id']?.toString() ??
          widget.orderDetails['id']?.toString() ??
          'N/A';

      debugPrint('🔍 Order date: $orderDate');
      debugPrint('🔍 Status: $status');
      debugPrint('🔍 Total quantity: $totalQuantity');
      debugPrint('🔍 Total amount: $totalAmount');

      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade700,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          leading: AppBackButton(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
          title: Text(
            'Track Order',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
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
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading order details...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDeliveryInfo,
                color: Colors.green.shade600,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernHeader(orderNumber, status, orderDate),
                      const SizedBox(height: 12),
                      _buildOrderItemsCard(
                          orderItems, totalQuantity, totalAmount),
                      const SizedBox(height: 12),
                      _buildStatusTimelineCard(status),
                      const SizedBox(height: 12),
                      _buildDeliveryDetailsCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      );
    } catch (e) {
      debugPrint('🔍 Error in OrderTrackingPage build: $e');
      return Scaffold(
        appBar: AppBar(
          title: Text('Track Order'),
          backgroundColor: Colors.green.shade700,
          leading: IconButton(
            onPressed: () {
              debugPrint(
                  '🔍 Back button pressed in OrderTrackingPage (error case)');
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            icon: Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading order tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Error: $e',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildModernHeader(
      String orderNumber, String status, DateTime? orderDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                if (orderDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(orderDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'delivered':
        statusColor = Colors.green.shade600;
        statusText = 'Delivered';
        break;
      case 'shipped':
      case 'out for delivery':
        statusColor = Colors.blue.shade600;
        statusText = 'Out for Delivery';
        break;
      case 'processing':
      case 'confirmed':
      case 'paid':
        statusColor = Colors.orange.shade600;
        statusText = 'Processing';
        break;
      case 'pending confirmation':
        statusColor = Colors.orange.shade600;
        statusText = 'Pending Confirmation';
        break;
      case 'order placed':
      case 'pending':
        statusColor = Colors.grey.shade600;
        statusText = 'Order Placed';
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusText = status.isNotEmpty ? status : 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        statusText.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusTimelineCard(String currentStatus) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildModernStatusTimeline(currentStatus),
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
    if (deliveryFee <= 0.01 && _actualDeliveryFee != null && _actualDeliveryFee! > 0.01) {
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
        debugPrint('🔍   ✅ Using calculated deliveryFee from difference: $deliveryFee');
      }
    }
    
    debugPrint('🔍   ===== Final deliveryFee: $deliveryFee =====');
    debugPrint('🔍   Will show delivery fee: ${deliveryFee > 0.01}');
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...orderItems.map((item) => _buildModernOrderItemRow(item)),
          const Divider(height: 12),
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
              
              debugPrint('🔍 Display Builder: finalDeliveryFee=$finalDeliveryFee, totalAmount=$totalAmount, subtotal=$subtotal, discount=$discount');
              
              // Always show if there's a meaningful delivery fee
              if (finalDeliveryFee > 0.01) {
                debugPrint('🔍 Display: ✅ SHOWING delivery fee: GHS ${finalDeliveryFee.toStringAsFixed(2)}');
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
                debugPrint('🔍   - calculated difference: ${totalAmount - subtotal + discount}');
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
    );
  }

  Widget _buildModernOrderItemRow(Map<String, dynamic> item) {
    final productName = item['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(item['product_img']);
    final qty = item['qty'] ?? 1;
    final price = (item['price'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              productImg,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 40,
                height: 40,
                color: Colors.grey.shade100,
                child: Icon(Icons.image_rounded,
                    color: Colors.grey.shade400, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: $qty',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'GHS ${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusTimeline(String currentStatus) {
    final statuses = [
      {
        'title': 'Order Placed',
        'status': 'pending',
        'icon': Icons.shopping_cart_rounded
      },
      {
        'title': 'Confirmed',
        'status': 'processing',
        'icon': Icons.verified_rounded
      },
      {
        'title': 'Shipped',
        'status': 'shipped',
        'icon': Icons.local_shipping_rounded
      },
      {
        'title': 'Delivered',
        'status': 'delivered',
        'icon': Icons.check_circle_rounded
      },
    ];

    final normalizedStatus = currentStatus.toLowerCase().trim();
    // Map API statuses to timeline steps: Order Placed, Paid, Pending Confirmation, Out for Delivery, Delivered
    String timelineStatus;
    if (normalizedStatus == 'order placed') {
      timelineStatus = 'pending';
    } else if (normalizedStatus == 'paid' || normalizedStatus == 'confirmed' || normalizedStatus == 'pending confirmation') {
      timelineStatus = 'processing';
    } else if (normalizedStatus == 'out for delivery') {
      timelineStatus = 'shipped';
    } else if (normalizedStatus == 'delivered') {
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.shade600
                        : isCurrent
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 2,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade400
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // Status content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  status['title'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent || isCompleted
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isCurrent
                        ? Colors.blue.shade700
                        : isCompleted
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  bool _isStatusCompleted(String status, String currentStatus) {
    final statusOrder = ['pending', 'processing', 'shipped', 'delivered'];
    
    // Normalize status: Order Placed->pending, Paid/Pending Confirmation->processing, Out for Delivery->shipped, Delivered->delivered
    final normalizedCurrentStatus = currentStatus.toLowerCase().trim();
    String normalizedStatus;
    if (normalizedCurrentStatus == 'order placed') {
      normalizedStatus = 'pending';
    } else if (normalizedCurrentStatus == 'paid' || normalizedCurrentStatus == 'confirmed' || normalizedCurrentStatus == 'pending confirmation') {
      normalizedStatus = 'processing';
    } else if (normalizedCurrentStatus == 'out for delivery') {
      normalizedStatus = 'shipped';
    } else if (normalizedCurrentStatus == 'delivered') {
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

  Widget _buildDeliveryDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
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
              Icon(
                Icons.location_on_rounded,
                size: 18,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _deliveryAddress ?? 'Not available',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.phone_rounded,
                size: 18,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Contact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _contactNumber ?? 'Not available',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 18,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Delivery Method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _deliveryOption ?? 'Standard Delivery',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
