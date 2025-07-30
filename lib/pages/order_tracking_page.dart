// pages/order_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_back_button.dart';
import '../widgets/cart_icon_button.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/delivery_service.dart';
import '../services/order_notification_service.dart';
import '../services/native_notification_service.dart';

class OrderTrackingPage extends StatefulWidget {
  final Map<String, dynamic> orderDetails;

  const OrderTrackingPage({
    super.key,
    required this.orderDetails,
  });

  @override
  _OrderTrackingPageState createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  String? _deliveryAddress;
  String? _contactNumber;
  String? _deliveryOption;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveryInfo();
  }

  Future<void> _loadDeliveryInfo() async {
    try {
      debugPrint('🔍 Loading delivery info for order tracking...');
      // Try to get delivery info from API first
      final deliveryResult = await DeliveryService.getLastDeliveryInfo();

      debugPrint('🔍 Delivery API result: ${deliveryResult['success']}');

      if (deliveryResult['success'] == true && deliveryResult['data'] != null) {
        final deliveryData = deliveryResult['data'];
        setState(() {
          // Build delivery address from components
          final region = deliveryData['region'] ?? '';
          final city = deliveryData['city'] ?? '';
          final address = deliveryData['address'] ?? '';

          if (deliveryData['delivery_option'] == 'delivery') {
            _deliveryAddress = '$address, $city, $region';
          } else {
            // For pickup, use pickup location
            final pickupRegion = deliveryData['pickup_region'] ?? '';
            final pickupCity = deliveryData['pickup_city'] ?? '';
            final pickupSite = deliveryData['pickup_site'] ??
                deliveryData['pickup_location'] ??
                '';
            _deliveryAddress = '$pickupSite, $pickupCity, $pickupRegion';
          }

          _contactNumber = deliveryData['phone'];
          _deliveryOption = deliveryData['delivery_option'];
          _isLoading = false;

          debugPrint('🔍 Loaded delivery info:');
          debugPrint('🔍 Address: $_deliveryAddress');
          debugPrint('🔍 Contact: $_contactNumber');
          debugPrint('🔍 Option: $_deliveryOption');
        });
      } else {
        // Fallback to SharedPreferences if API fails
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _deliveryAddress = prefs.getString('delivery_address');
          _contactNumber = prefs.getString('userPhoneNumber');
          _deliveryOption = prefs.getString('delivery_option');
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading delivery info: $e');
      // Fallback to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _deliveryAddress = prefs.getString('delivery_address');
          _contactNumber = prefs.getString('userPhoneNumber');
          _deliveryOption = prefs.getString('delivery_option');
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final theme = Theme.of(context);
    final orderDate =
        DateTime.tryParse(widget.orderDetails['created_at'] ?? '');
    final status = widget.orderDetails['status'] ?? 'Processing';
    final orderItems = getOrderItems();
    final totalQuantity = getTotalQuantity();
    final totalAmount = getTotalAmount();

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
        leading: BackButtonUtils.simple(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
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
