// pages/purchases.dart
import 'package:eclapp/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Cart.dart';
import 'CartItem.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'AppBackButton.dart';
import 'HomePage.dart';
import 'auth_service.dart';

import '../widgets/cart_icon_button.dart';
import 'order_tracking_page.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  _PurchaseScreenState createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
    });
  }

  Future<void> _fetchOrders() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final result = await AuthService.getOrders();
      print('\n=== FETCHING ORDERS ===');
      print('Result status: ${result['status']}');
      print('Result message: ${result['message']}');
      print('Result data type: ${result['data'].runtimeType}');

      if (result['status'] == 'success' && result['data'] is List) {
        if (mounted) {
          // Group orders by transaction ID first, then fall back to time-based grouping
          final rawOrders = result['data'] as List;
          print('Raw orders count: ${rawOrders.length}');
          print('Raw orders: ${rawOrders.map((order) => {
                'id': order['order_id'] ??
                    order['transaction_id'] ??
                    order['delivery_id'],
                'product_name': order['product_name'],
                'payment_method': order['payment_method'],
                'created_at': order['created_at'],
              }).toList()}');
          final Map<String, List<dynamic>> groupedOrders = {};

          print('Raw orders count: ${rawOrders.length}');

          // First, try to group by transaction_id, order_id, or delivery_id
          for (final order in rawOrders) {
            print('Processing order: ${order.toString()}');
            print('Available fields: ${order.keys.toList()}');

            // Use order_id, transaction_id, or delivery_id as the unique identifier
            final transactionId = order['order_id'] ??
                order['transaction_id'] ??
                order['delivery_id'] ??
                'unknown_${DateTime.now().millisecondsSinceEpoch}';

            print('Using transactionId: $transactionId');

            if (!groupedOrders.containsKey(transactionId)) {
              groupedOrders[transactionId] = [];
            }
            groupedOrders[transactionId]!.add(order);
          }

          print(
              'Transaction ID grouping complete. Groups: ${groupedOrders.length}');

          // Check if transaction ID grouping worked well
          // If we have many single-item groups, try time-based grouping
          final singleItemGroups =
              groupedOrders.values.where((orders) => orders.length == 1).length;
          final totalGroups = groupedOrders.length;

          print(
              'Single item groups: $singleItemGroups out of $totalGroups total groups');

          if (singleItemGroups > totalGroups * 0.7) {
            // If more than 70% are single items, try time-based grouping
            print(
                'Many single-item groups detected, attempting time-based grouping...');

            // Reset grouping
            groupedOrders.clear();

            // Sort orders by creation date
            final sortedOrders = List<dynamic>.from(rawOrders);
            sortedOrders.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
              final dateB =
                  DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
              return dateA.compareTo(dateB);
            });

            print('Sorted orders by date:');
            for (int i = 0; i < sortedOrders.length; i++) {
              final order = sortedOrders[i];
              final date = DateTime.tryParse(order['created_at'] ?? '') ??
                  DateTime(1970);
              print('Order $i: ${order['product_name']} - ${date.toString()}');
            }

            // Group orders created within 10 minutes of each other
            // BUT respect transaction IDs - don't group orders with different transaction IDs
            const groupingWindow = Duration(minutes: 10);
            String currentGroupKey = '';
            DateTime? lastOrderTime;
            String? lastTransactionId;

            for (final order in sortedOrders) {
              final orderTime = DateTime.tryParse(order['created_at'] ?? '') ??
                  DateTime.now();
              final currentTransactionId = order['order_id'] ??
                  order['transaction_id'] ??
                  order['delivery_id'] ??
                  'unknown_${orderTime.millisecondsSinceEpoch}';

              // Start a new group if:
              // 1. It's the first order, OR
              // 2. More than 10 minutes have passed, OR
              // 3. The transaction ID is different (different order)
              if (lastOrderTime == null ||
                  orderTime.difference(lastOrderTime!) > groupingWindow ||
                  currentTransactionId != lastTransactionId) {
                // Start a new group
                currentGroupKey =
                    'group_${currentTransactionId}_${orderTime.millisecondsSinceEpoch}';
                lastOrderTime = orderTime;
                lastTransactionId = currentTransactionId;
                print(
                    'Starting new group: $currentGroupKey for ${order['product_name'] ?? 'Unknown Product'} (Transaction: $currentTransactionId) at ${orderTime.toString()}');
              } else {
                print(
                    'Adding to existing group: $currentGroupKey for ${order['product_name'] ?? 'Unknown Product'} (Transaction: $currentTransactionId) (${orderTime.difference(lastOrderTime!).inMinutes} minutes apart)');
              }

              if (!groupedOrders.containsKey(currentGroupKey)) {
                groupedOrders[currentGroupKey] = [];
              }
              groupedOrders[currentGroupKey]!.add(order);
            }

            print(
                'Time-based grouping complete. Groups: ${groupedOrders.length}');
          } else {
            print(
                'Transaction ID grouping worked well, keeping existing groups');
          }

          groupedOrders.forEach((key, orders) {
            print('Group $key: ${orders.length} items');
            for (final order in orders) {
              print('  - ${order['product_name']} (${order['created_at']})');
            }
          });

          // Convert grouped orders to a list of combined orders
          final combinedOrders = groupedOrders.entries.map((entry) {
            final orders = entry.value;
            print('Processing group ${entry.key} with ${orders.length} items');

            if (orders.length == 1) {
              // Single item order - return as is
              final order = orders.first;
              print('Single item order: ${order['product_name']}');

              // Handle local orders with items array structure
              if (order.containsKey('items') &&
                  order['items'] is List &&
                  (order['items'] as List).isNotEmpty) {
                final items = order['items'] as List;
                final firstItem = items[0];

                // If there are multiple items, mark as multi-item order
                if (items.length > 1) {
                  print(
                      'Local order with multiple items: ${items.length} items');
                  return {
                    ...order,
                    'product_name':
                        firstItem['product_name'] ?? 'Unknown Product',
                    'product_img': firstItem['product_img'] ?? '',
                    'qty': items.fold<int>(
                        0, (sum, item) => sum + ((item['qty'] ?? 1) as int)),
                    'price': firstItem['price'] ?? 0.0,
                    'total_price': order['total_price'] ?? 0.0,
                    'is_multi_item': true,
                    'item_count': items.length,
                    'order_items': items
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList(),
                  };
                } else {
                  print(
                      'Local order with single item: ${firstItem['product_name']}');
                  return {
                    ...order,
                    'product_name':
                        firstItem['product_name'] ?? 'Unknown Product',
                    'product_img': firstItem['product_img'] ?? '',
                    'qty': firstItem['qty'] ?? 1,
                    'price': firstItem['price'] ?? 0.0,
                    'batch_no': firstItem['batch_no'] ?? '',
                  };
                }
              }

              return order;
            } else {
              // Multi-item order - combine into one order
              final firstOrder = orders.first;
              print('Multi-item order with ${orders.length} items');

              // Handle local orders with items array structure
              if (firstOrder.containsKey('items') &&
                  firstOrder['items'] is List) {
                final orderItems = firstOrder['items'] as List;
                final firstItem = orderItems.isNotEmpty ? orderItems.first : {};

                // Calculate totals from all items in all orders
                double totalAmount = 0.0;
                int totalQuantity = 0;
                List<Map<String, dynamic>> allItems = [];

                for (final order in orders) {
                  if (order.containsKey('items') && order['items'] is List) {
                    final items = order['items'] as List;
                    for (final item in items) {
                      allItems.add(Map<String, dynamic>.from(item));
                      totalAmount += (item['price'] ?? 0.0).toDouble() *
                          (item['qty'] ?? 1);
                      totalQuantity += (item['qty'] ?? 1) as int;
                    }
                  }
                }

                print(
                    'Local multi-item order: ${allItems.length} total items, total amount: $totalAmount');
                return {
                  ...firstOrder,
                  'product_name':
                      firstItem['product_name'] ?? 'Unknown Product',
                  'product_img': firstItem['product_img'] ?? '',
                  'qty': totalQuantity,
                  'price': firstItem['price'] ?? 0.0,
                  'total_price': totalAmount,
                  'is_multi_item': true,
                  'item_count': allItems.length,
                };
              } else {
                // Handle server orders (existing logic)
                final orderItems = orders
                    .map((order) => {
                          'product_name':
                              order['product_name'] ?? 'Unknown Product',
                          'product_img': order['product_img'] ?? '',
                          'qty': order['qty'] ?? 1,
                          'price': order['price'] ?? 0.0,
                          'batch_no': order['batch_no'] ?? '',
                        })
                    .toList();

                // Calculate totals
                final totalQuantity = orders.fold<int>(
                    0, (sum, order) => sum + (order['qty'] ?? 1) as int);
                final totalAmount = orders.fold<double>(0.0, (sum, order) {
                  final price = (order['price'] ?? 0.0).toDouble();
                  final qty = order['qty'] ?? 1;
                  return sum + (price * qty);
                });

                print(
                    'Server multi-item order: Combined ${orders.length} items into single order with total quantity: $totalQuantity, total amount: $totalAmount');

                return {
                  ...firstOrder,
                  'order_items': orderItems,
                  'qty': totalQuantity,
                  'total_price': totalAmount,
                  'is_multi_item': true,
                  'item_count': orders.length,
                };
              }
            }
          }).toList();

          setState(() {
            _orders = combinedOrders;
            print('\n=== FINAL COMBINED ORDERS ===');
            for (int i = 0; i < combinedOrders.length; i++) {
              final order = combinedOrders[i];
              print(
                  'Order $i: ${order['product_name']} - Qty: ${order['qty']} - Total: ${order['total_price']} - Multi-item: ${order['is_multi_item']} - Item count: ${order['item_count']}');
            }
            _orders.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
              final dateB =
                  DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
              return dateB.compareTo(dateA); // Descending: latest first
            });
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = result['message'] ?? 'Failed to load orders';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred while loading orders';
          _isLoading = false;
        });
      }
    }
  }

  String getImageUrl(String? url) {
    print('getImageUrl called with: "$url"');

    if (url == null || url.isEmpty || url == 'default_product.png') {
      print('getImageUrl: returning empty string for null/empty URL');
      return '';
    }

    if (url.startsWith('http')) {
      print('getImageUrl: returning full URL: $url');
      return url;
    }

    if (url.startsWith('/uploads/')) {
      final fullUrl = 'https://adm-ecommerce.ernestchemists.com.gh$url';
      print('getImageUrl: returning uploads URL: $fullUrl');
      return fullUrl;
    }

    if (url.startsWith('/storage/')) {
      final fullUrl = 'https://eclcommerce.ernestchemists.com.gh$url';
      print('getImageUrl: returning storage URL: $fullUrl');
      return fullUrl;
    }

    // For relative paths (like _1750059953_Gastrone-original-200ml.png)
    final fullUrl =
        'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
    print('getImageUrl: returning product URL: $fullUrl');
    return fullUrl;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  height: 300,
                  width: 300,
                  child: const Icon(Icons.error_outline,
                      color: Colors.red, size: 60),
                ),
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  height: 300,
                  width: 300,
                  child: const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final orderDate = DateTime.tryParse(order['created_at'] ?? '');
    final isMultiItem = order['is_multi_item'] == true;
    final itemCount = order['item_count'] ?? 1;
    final paymentMethod = order['payment_method'] ?? '';
    final isCashOnDelivery =
        paymentMethod.toLowerCase().contains('cash on delivery');

    // For multi-item orders, show first item as representative
    final productName = isMultiItem
        ? '${order['product_name'] ?? 'Unknown Product'} + ${itemCount - 1} more items'
        : order['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(order['product_img']);
    print('_buildOrderCard: Product name: $productName');
    print('_buildOrderCard: Original image URL: ${order['product_img']}');
    print('_buildOrderCard: Processed image URL: $productImg');
    final qty = order['qty'] ?? 1;
    final price = order['price'] ?? 0.0;
    final total = order['total_price'] ?? 0.0;
    final status = order['status'] ?? 'Processing';

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          print('Order tapped: ' + order.toString());
          print('Order type: ' + order.runtimeType.toString());
          try {
            final castedOrder = Map<String, dynamic>.from(order);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderTrackingPage(
                  orderDetails: castedOrder,
                ),
              ),
            );
          } catch (e) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Error'),
                content: Text('Order data is invalid. Please contact support.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    orderDate != null
                        ? DateFormat('MMM dd, yyyy').format(orderDate)
                        : 'Date unavailable',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Spacer(),
                  if (isMultiItem) ...[
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$itemCount items',
                        style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  if (isCashOnDelivery) ...[
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'COD',
                        style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => productImg.isNotEmpty
                        ? _showFullImageDialog(productImg)
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: productImg.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: productImg,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error_outline,
                                    color: Colors.red),
                              ),
                              httpHeaders: const {
                                'User-Agent':
                                    'Mozilla/5.0 (compatible; Flutter)',
                              },
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.grey,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Qty: $qty',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Order ID: ${order['delivery_id'] ?? order['order_id'] ?? 'N/A'}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        if (isCashOnDelivery) ...[
                          SizedBox(height: 4),
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        SizedBox(height: 4),
                        Text(
                          'GHS ${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 100,
              color: Colors.green[200],
            ),
            const SizedBox(height: 30),
            Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 24,
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start shopping to see your orders here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Profile(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Shop Now', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Error Loading Orders',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _filterOrders(String query) {
    setState(() {
      if (query.isEmpty) {
        _orders = _orders;
      } else {
        _orders = _orders.where((order) {
          final productName = order['product_name'] ?? 'Unknown Product';
          return productName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
      ),
    );
  }

  Widget _buildOrderList() {
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: Colors.green,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          double fontSize =
              screenWidth < 400 ? 13 : (screenWidth < 600 ? 15 : 17);
          double cardPadding =
              screenWidth < 400 ? 10 : (screenWidth < 600 ? 16 : 24);
          double imageSize =
              screenWidth < 400 ? 48 : (screenWidth < 600 ? 64 : 80);
          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(_orders[index]);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const Profile(),
              ),
            );
          },
        ),
        title: Text(
          'Your Orders',
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
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchOrders,
              tooltip: 'Refresh',
            ),
          ),
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
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _orders.isEmpty
                  ? _buildEmptyState()
                  : _buildOrderList(),
      bottomNavigationBar: CustomBottomNav(
        initialIndex:
            0, // Don't set profile as selected, so tapping profile will navigate
      ),
    );
  }
}
