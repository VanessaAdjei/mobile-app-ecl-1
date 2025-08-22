// pages/order_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_back_button.dart';
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

      debugPrint('🔍 Order date: $orderDate');
      debugPrint('🔍 Status: $status');
      debugPrint('🔍 Total quantity: $totalQuantity');
      debugPrint('🔍 Total amount: $totalAmount');

      return Scaffold(
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
                  Colors.green.shade700,
                  Colors.green.shade800,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
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
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDeliveryInfo,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderSummaryCard(
                          orderDate, orderItems, totalQuantity, totalAmount),
                      SizedBox(height: 16),
                      _buildStatusCard(status),
                      SizedBox(height: 16),
                      _buildDeliveryDetailsCard(),
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

  Widget _buildOrderSummaryCard(
      DateTime? orderDate,
      List<Map<String, dynamic>> orderItems,
      int totalQuantity,
      double totalAmount) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            // Show order items
            ...orderItems.map((item) => _buildOrderItemRow(item)),
            Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Date',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  orderDate != null
                      ? DateFormat('MMM dd, yyyy').format(orderDate)
                      : 'N/A',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  formatQuantityText(totalQuantity),
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'GHS ${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemRow(Map<String, dynamic> item) {
    final productName = item['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(item['product_img']);
    final qty = item['qty'] ?? 1;
    final price = (item['price'] ?? 0.0).toDouble();
    final batchNo = item['batch_no'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              productImg,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: Icon(Icons.error_outline, color: Colors.red),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Qty: $qty',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (batchNo.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    'Batch: $batchNo',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                SizedBox(height: 4),
                Text(
                  'GHS ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String currentStatus) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Status',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildStatusTimeline(currentStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final statuses = [
      {
        'icon': Icons.shopping_cart,
        'title': 'Order Placed',
        'status': 'pending'
      },
      {
        'icon': Icons.check_circle,
        'title': 'Order Confirmed',
        'status': 'processing'
      },
      {
        'icon': Icons.local_shipping,
        'title': 'Out for Delivery',
        'status': 'shipped'
      },
      {'icon': Icons.home, 'title': 'Delivered', 'status': 'delivered'},
    ];

    // Normalize the current status
    final normalizedStatus = currentStatus.toLowerCase().trim();
    // Debug print

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final statusStr = status['status'] as String;
        final isCompleted = _isStatusCompleted(statusStr, normalizedStatus);
        final isCurrent = statusStr == normalizedStatus;

        // Debug print

        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green[700] : Colors.grey[300],
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: Colors.green[700]!, width: 2)
                    : null,
              ),
              child: Icon(
                status['icon'] as IconData,
                color: isCompleted ? Colors.white : Colors.grey[600],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status['title'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isCurrent
                          ? Colors.green[700]
                          : isCompleted
                              ? Colors.black87
                              : Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (index < statuses.length - 1)
                    Container(
                      height: 1,
                      color: isCompleted
                          ? Colors.green[700]!.withValues(alpha: 0.2)
                          : Colors.grey[300],
                    ),
                ],
              ),
            ),
          ],
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Details',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            if (_deliveryAddress == 'Address not available' ||
                _contactNumber == 'Contact not available') ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delivery details are being loaded from your saved delivery information. '
                        'If you haven\'t set up delivery details yet, please visit the delivery page to add them.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            _buildInfoRow(
              Icons.location_on,
              'Delivery Address',
              _deliveryAddress ?? 'Address not available',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.phone,
              'Contact Number',
              _contactNumber ?? 'Contact number not available',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.local_shipping,
              'Delivery Method',
              _deliveryOption ?? 'Standard Delivery',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
