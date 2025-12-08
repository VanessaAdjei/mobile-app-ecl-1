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

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 OrderTrackingPage initState called');
    debugPrint('🔍 Order details in initState: ${widget.orderDetails}');
    debugPrint(
        'Current navigation stack depth: ${Navigator.of(context).widget.observers.length}');
    debugPrint('Can pop current context: ${Navigator.canPop(context)}');
    _loadDeliveryInfo();
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

      // If we don't have delivery info from notification, try to fetch from API
      if (notificationAddress == null || notificationAddress.isEmpty) {
        if (isLoggedIn) {
          debugPrint(
              '🔍 No delivery address in notification, trying to fetch from API...');

          // Check if we have a delivery_id that might be useful
          final deliveryId = orderDetails['delivery_id']?.toString();
          if (deliveryId != null && deliveryId.isNotEmpty) {
            debugPrint(
                '🔍 Found delivery_id: $deliveryId - this might contain delivery info');
          }

          // First try to get delivery info from the user's saved delivery data
          debugPrint('🔍 Trying to fetch user\'s saved delivery info...');
          final deliveryResult = await DeliveryService.getLastDeliveryInfo();

          if (deliveryResult['success'] && deliveryResult['data'] != null) {
            final deliveryData = deliveryResult['data'];
            debugPrint('🔍 Successfully fetched delivery info: $deliveryData');

            // Extract delivery information from the saved delivery data
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

            // Extract contact information
            final savedContact = deliveryData['phone']?.toString();
            if (savedContact != null && savedContact.isNotEmpty) {
              notificationContact = savedContact;
              debugPrint('🔍 Found saved contact number: $notificationContact');
            }

            // Extract delivery option
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

      // Fall back to SharedPreferences if still no delivery info
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
        _isLoading = false;
      });

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
        _isLoading = false;
      });
    }
  }

  // Try to fetch order details from API to get delivery information
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

      // Get auth token using the proper AuthService
      final token = await AuthService.getToken();

      if (token == null) {
        debugPrint('🔍 No auth token available for API call');
        debugPrint('🔍 User might not be logged in or token expired');
        return;
      }

      debugPrint(
          '🔍 Auth token retrieved successfully: ${token.substring(0, 20)}...');

      // Try to get all orders and find the specific one we need
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

          // Check if API response indicates success
          final apiStatus = ordersData['status']?.toString();
          if (apiStatus != 'success') {
            debugPrint('🔍 API response status is not success: $apiStatus');
            return;
          }

          // Use 'data' field instead of 'orders' based on actual API response structure
          final orders = ordersData['data'] ?? [];
          debugPrint('🔍 Total orders received: ${orders.length}');

          // Check if orders are in a different field (fallback)
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

          // Debug: Show what we're looking for
          debugPrint('🔍 Looking for order with:');
          debugPrint('🔍   - orderId: $orderId');
          debugPrint('🔍   - orderNumber: $orderNumber');
          debugPrint(
              '🔍   - notification delivery_id: ${widget.orderDetails['delivery_id']}');

          // Debug: Show first few orders to understand structure
          if (orders.isNotEmpty) {
            debugPrint('🔍 Sample orders from API:');
            for (int i = 0; i < orders.length && i < 5; i++) {
              final order = orders[i];
              debugPrint(
                  '🔍 Order ${i + 1}: ID=${order['id']}, Delivery ID=${order['delivery_id']}, User ID=${order['user_id']}');
            }
          }

          // Try multiple matching strategies
          Map<String, dynamic>? targetOrder;

          // Strategy 1: Try to match by delivery_id (most reliable for notifications)
          final notificationDeliveryId =
              widget.orderDetails['delivery_id']?.toString();
          if (notificationDeliveryId != null &&
              notificationDeliveryId.isNotEmpty) {
            debugPrint(
                '🔍 Trying to match by delivery_id from notification: $notificationDeliveryId');
            targetOrder = orders.firstWhere(
              (order) => order['delivery_id'] == notificationDeliveryId,
              orElse: () => null,
            );
            if (targetOrder != null) {
              debugPrint(
                  '🔍 Found order by delivery_id: ${targetOrder['delivery_id']}');
            }
          }

          // Strategy 2: Try to match by order number (if different from delivery_id)
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

          // Strategy 3: Try to match by numeric ID (extract from ORDER_ prefix) - less reliable
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

          // Strategy 4: Try to match by order ID as string (fallback)
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

            // Extract delivery information from the found order
            // Note: The API response doesn't seem to have delivery address fields
            // We'll use what's available and show a message about missing delivery info
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

            // If we still don't have delivery info, show a message
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

    // Single item order - create a single item map
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

  // Calculate total quantity across all items
  int getTotalQuantity() {
    return getOrderItems()
        .fold(0, (sum, item) => sum + (item['qty'] ?? 1) as int);
  }

  // Calculate total amount across all items
  double getTotalAmount() {
    return getOrderItems().fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0.0).toDouble();
      final qty = item['qty'] ?? 1;
      return sum + (price * qty);
    });
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
      final status = widget.orderDetails['status'] ?? 'Processing';
      final orderItems = getOrderItems();
      final totalQuantity = getTotalQuantity();
      final totalAmount = getTotalAmount();
      final orderNumber = widget.orderDetails['order_number'] ??
          widget.orderDetails['delivery_id'] ??
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
          leading: IconButton(
            onPressed: () {
              debugPrint('🔍 Back button pressed in OrderTrackingPage');
              debugPrint('🔍 Can pop: ${Navigator.canPop(context)}');
              if (Navigator.canPop(context)) {
                debugPrint('🔍 Popping back to previous page (notifications)');
                Navigator.pop(context);
              } else {
                debugPrint('🔍 Cannot pop, navigating to home');
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
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
                      style: GoogleFonts.poppins(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernHeader(orderNumber, status, orderDate),
                      SizedBox(height: 8),
                      _buildOrderItemsCard(
                          orderItems, totalQuantity, totalAmount),
                      SizedBox(height: 8),
                      _buildStatusTimelineCard(status),
                      SizedBox(height: 8),
                      _buildDeliveryDetailsCard(),
                      SizedBox(height: 20),
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
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Error: $e',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
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
      margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderNumber',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      orderDate != null
                          ? DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(orderDate)
                          : 'Date not available',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.green.shade600,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'Track your order in real-time',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'delivered':
        statusColor = Colors.green;
        statusText = 'Delivered';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'shipped':
      case 'out for delivery':
        statusColor = Colors.blue;
        statusText = 'Shipped';
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'processing':
      case 'confirmed':
        statusColor = Colors.orange;
        statusText = 'Processing';
        statusIcon = Icons.settings_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Pending';
        statusIcon = Icons.schedule_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            statusText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimelineCard(String currentStatus) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Progress',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          _buildModernStatusTimeline(currentStatus),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(List<Map<String, dynamic>> orderItems,
      int totalQuantity, double totalAmount) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Items',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formatQuantityText(totalQuantity),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...orderItems.map((item) => _buildModernOrderItemRow(item)),
          Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'GHS ${totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
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
    final batchNo = item['batch_no'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image
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
                color: Colors.grey[100],
                child: Icon(Icons.image_rounded,
                    color: Colors.grey[400], size: 18),
              ),
            ),
          ),
          SizedBox(width: 10),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // Quantity Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Qty: $qty',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Price
          Text(
            'GHS ${price.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusTimeline(String currentStatus) {
    final statuses = [
      {
        'icon': Icons.shopping_cart_rounded,
        'title': 'Order Placed',
        'description': 'Your order has been received',
        'status': 'pending'
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Order Confirmed',
        'description': 'We\'re preparing your order',
        'status': 'processing'
      },
      {
        'icon': Icons.local_shipping_rounded,
        'title': 'Out for Delivery',
        'description': 'Your order is on the way',
        'status': 'shipped'
      },
      {
        'icon': Icons.home_rounded,
        'title': 'Delivered',
        'description': 'Order delivered successfully',
        'status': 'delivered'
      },
    ];

    final normalizedStatus = currentStatus.toLowerCase().trim();

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final statusStr = status['status'] as String;
        final isCompleted = _isStatusCompleted(statusStr, normalizedStatus);
        final isCurrent = statusStr == normalizedStatus;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade600
                          : isCurrent
                              ? Colors.blue.shade600
                              : Colors.grey[300],
                      shape: BoxShape.circle,
                      boxShadow: isCompleted || isCurrent
                          ? [
                              BoxShadow(
                                color:
                                    (isCompleted ? Colors.green : Colors.blue)
                                        .shade600
                                        .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      status['icon'] as IconData,
                      color: isCompleted || isCurrent
                          ? Colors.white
                          : Colors.grey[600],
                      size: 18,
                    ),
                  ),
                  if (index < statuses.length - 1)
                    Container(
                      width: 2,
                      height: 24,
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade300
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status['title'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? Colors.blue.shade600
                            : isCompleted
                                ? Colors.green.shade600
                                : Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      status['description'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isCurrent) ...[
                      SizedBox(height: 6),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Current Status',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  bool _isStatusCompleted(String status, String currentStatus) {
    final statusOrder = ['pending', 'processing', 'shipped', 'delivered'];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final statusIndex = statusOrder.indexOf(status);

    // If current status is not in the list, treat it as 'pending'
    if (currentIndex == -1) {
      return status == 'pending';
    }

    return statusIndex <= currentIndex;
  }

  Widget _buildDeliveryDetailsCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                color: Colors.green.shade600,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'Delivery Details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (_deliveryAddress == 'Address not available' ||
              _contactNumber == 'Contact not available') ...[
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange.shade600, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivery details are being loaded from your saved delivery information.',
                      style: GoogleFonts.poppins(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
          ],
          _buildModernInfoRow(
            Icons.location_on_rounded,
            'Delivery Address',
            _deliveryAddress ?? 'Address not available',
            Colors.red.shade600,
          ),
          SizedBox(height: 8),
          _buildModernInfoRow(
            Icons.phone_rounded,
            'Contact Number',
            _contactNumber ?? 'Contact number not available',
            Colors.blue.shade600,
          ),
          SizedBox(height: 8),
          _buildModernInfoRow(
            Icons.local_shipping_rounded,
            'Delivery Method',
            _deliveryOption ?? 'Standard Delivery',
            Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(
      IconData icon, String title, String value, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
