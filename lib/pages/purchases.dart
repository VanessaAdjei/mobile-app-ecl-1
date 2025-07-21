// pages/purchases.dart
import 'package:eclapp/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bottomnav.dart';
import 'AppBackButton.dart';
import 'auth_service.dart';

import '../widgets/cart_icon_button.dart';
import 'order_tracking_page.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  _PurchaseScreenState createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final Set<String> _expandedOrders = {};
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

      if (result['status'] == 'success' && result['data'] is List) {
        if (mounted) {
          final rawOrders = result['data'] as List;

          // Debug: Log basic order info
          print('Total raw orders: ${rawOrders.length}');

          final Map<String, List<dynamic>> groupedOrders = {};

          // Group orders by transaction ID (order_id, transaction_id, or delivery_id)
          for (final order in rawOrders) {
            // Skip invalid orders
            if (!_isValidOrder(order)) {
              print('Skipping invalid order: $order');
              continue;
            }

            // For cash on delivery orders, prioritize delivery_id for grouping
            String transactionId;
            final paymentMethod =
                order['payment_method'] ?? order['payment_type'] ?? '';
            final isCashOnDelivery = _isCashOnDelivery(paymentMethod);

            if (isCashOnDelivery) {
              // For COD orders, use delivery_id as primary grouping key
              if (order['delivery_id'] != null &&
                  order['delivery_id'].toString().isNotEmpty) {
                transactionId = order['delivery_id'].toString();
              } else if (order['order_id'] != null &&
                  order['order_id'].toString().isNotEmpty) {
                transactionId = order['order_id'].toString();
              } else if (order['transaction_id'] != null &&
                  order['transaction_id'].toString().isNotEmpty) {
                transactionId = order['transaction_id'].toString();
              } else {
                // Fallback for COD orders without proper IDs
                final timestamp =
                    order['created_at'] ?? DateTime.now().toIso8601String();
                final productName = order['product_name'] ?? 'unknown';
                transactionId = 'cod_${timestamp}_${productName}';
              }
            } else {
              // For non-COD orders, use the existing logic
              if (order['order_id'] != null &&
                  order['order_id'].toString().isNotEmpty) {
                transactionId = order['order_id'].toString();
              } else if (order['transaction_id'] != null &&
                  order['transaction_id'].toString().isNotEmpty) {
                transactionId = order['transaction_id'].toString();
              } else if (order['delivery_id'] != null &&
                  order['delivery_id'].toString().isNotEmpty) {
                transactionId = order['delivery_id'].toString();
              } else {
                // If no reliable ID, use a combination of timestamp and product info
                final timestamp =
                    order['created_at'] ?? DateTime.now().toIso8601String();
                final productName = order['product_name'] ?? 'unknown';
                final price = order['price'] ?? 0.0;
                final qty = order['qty'] ?? 1;
                transactionId = '${timestamp}_${productName}_${price}_${qty}';
              }
            }

            print(
                'Processing order: ${order['product_name']} with transactionId: $transactionId (payment: $paymentMethod, COD: $isCashOnDelivery)');

            if (!groupedOrders.containsKey(transactionId)) {
              groupedOrders[transactionId] = [];
            }
            groupedOrders[transactionId]!.add(order);
          }

          // Post-process: Group COD orders that were created within 30 seconds of each other
          final codGroups = <String, List<dynamic>>{};
          final processedOrders = <dynamic>{};

          for (final entry in groupedOrders.entries) {
            final orders = entry.value;
            final firstOrder = orders.first;
            final paymentMethod = firstOrder['payment_method'] ??
                firstOrder['payment_type'] ??
                '';
            final isCashOnDelivery = _isCashOnDelivery(paymentMethod);

            if (isCashOnDelivery && orders.length == 1) {
              // This is a single COD order, check if it should be grouped with others
              final orderCreatedAt =
                  DateTime.tryParse(firstOrder['created_at'] ?? '');
              final orderId = firstOrder['order_id']?.toString() ?? '';
              print(
                  'COD order ${firstOrder['product_name']} created at: ${firstOrder['created_at']} (${orderCreatedAt?.millisecondsSinceEpoch}), order_id: $orderId');

              if (orderCreatedAt != null) {
                bool grouped = false;

                // Check if this order should be grouped with existing COD orders
                for (final existingGroup in codGroups.entries) {
                  final existingOrders = existingGroup.value;
                  final existingFirstOrder = existingOrders.first;
                  final existingCreatedAt =
                      DateTime.tryParse(existingFirstOrder['created_at'] ?? '');
                  final existingOrderId =
                      existingFirstOrder['order_id']?.toString() ?? '';

                  if (existingCreatedAt != null) {
                    final timeDifference =
                        orderCreatedAt.difference(existingCreatedAt).abs();
                    print(
                        '  Comparing with ${existingFirstOrder['product_name']} (${existingFirstOrder['created_at']}): ${timeDifference.inSeconds}s difference');

                    // Group if within 30 seconds OR if order IDs are sequential (within 1000 of each other)
                    bool shouldGroup = false;
                    String groupReason = '';

                    if (timeDifference.inSeconds <= 300) {
                      // Within 5 minutes
                      shouldGroup = true;
                      groupReason =
                          'time proximity (${timeDifference.inSeconds}s)';
                    } else if (orderId.isNotEmpty &&
                        existingOrderId.isNotEmpty) {
                      // Check if order IDs are sequential (likely same purchase)
                      try {
                        // Extract numeric part from ORDER_1750773938429 format
                        final currentIdMatch =
                            RegExp(r'ORDER_(\d+)').firstMatch(orderId);
                        final existingIdMatch =
                            RegExp(r'ORDER_(\d+)').firstMatch(existingOrderId);

                        if (currentIdMatch != null && existingIdMatch != null) {
                          final currentId =
                              int.tryParse(currentIdMatch.group(1)!);
                          final existingId =
                              int.tryParse(existingIdMatch.group(1)!);

                          if (currentId != null && existingId != null) {
                            final idDifference = (currentId - existingId).abs();
                            print(
                                '    Order ID comparison: $currentId vs $existingId (diff: $idDifference)');
                            if (idDifference <= 1000) {
                              // Within 1000 of each other
                              shouldGroup = true;
                              groupReason =
                                  'sequential order IDs (diff: $idDifference)';
                            }
                          }
                        } else {
                          // Fallback: try to extract any numbers from the order IDs
                          final currentNumbers =
                              orderId.replaceAll(RegExp(r'[^0-9]'), '');
                          final existingNumbers =
                              existingOrderId.replaceAll(RegExp(r'[^0-9]'), '');

                          if (currentNumbers.isNotEmpty &&
                              existingNumbers.isNotEmpty) {
                            final currentId = int.tryParse(currentNumbers);
                            final existingId = int.tryParse(existingNumbers);

                            if (currentId != null && existingId != null) {
                              final idDifference =
                                  (currentId - existingId).abs();
                              print(
                                  '    Order ID comparison (fallback): $currentId vs $existingId (diff: $idDifference)');
                              if (idDifference <= 1000) {
                                // Within 1000 of each other
                                shouldGroup = true;
                                groupReason =
                                    'sequential order IDs (diff: $idDifference)';
                              }
                            }
                          }
                        }
                      } catch (e) {
                        print('    Error parsing order IDs: $e');
                        // Ignore parsing errors
                      }
                    }

                    if (shouldGroup) {
                      // Group these orders together
                      existingOrders.add(firstOrder);
                      processedOrders.add(firstOrder);
                      grouped = true;
                      print(
                          'Grouped COD order ${firstOrder['product_name']} with existing group ($groupReason)');
                      break;
                    }
                  }
                }

                if (!grouped) {
                  // Create a new group for this COD order
                  final groupKey =
                      'cod_group_${orderCreatedAt.millisecondsSinceEpoch}';
                  codGroups[groupKey] = [firstOrder];
                  processedOrders.add(firstOrder);
                  print(
                      'Created new COD group for ${firstOrder['product_name']}');
                }
              } else {
                // Can't parse date, keep as individual order
                processedOrders.add(firstOrder);
              }
            } else {
              // Non-COD order or already grouped order, keep as is
              for (final order in orders) {
                processedOrders.add(order);
              }
            }
          }

          // Rebuild groupedOrders with the new COD groups
          final finalGroupedOrders = <String, List<dynamic>>{};

          // Add COD groups
          for (final entry in codGroups.entries) {
            finalGroupedOrders[entry.key] = entry.value;
          }

          // Add non-COD orders
          for (final order in processedOrders) {
            final paymentMethod =
                order['payment_method'] ?? order['payment_type'] ?? '';
            final isCashOnDelivery = _isCashOnDelivery(paymentMethod);

            if (!isCashOnDelivery) {
              // Re-group non-COD orders using original logic
              String transactionId;
              if (order['order_id'] != null &&
                  order['order_id'].toString().isNotEmpty) {
                transactionId = order['order_id'].toString();
              } else if (order['transaction_id'] != null &&
                  order['transaction_id'].toString().isNotEmpty) {
                transactionId = order['transaction_id'].toString();
              } else if (order['delivery_id'] != null &&
                  order['delivery_id'].toString().isNotEmpty) {
                transactionId = order['delivery_id'].toString();
              } else {
                final timestamp =
                    order['created_at'] ?? DateTime.now().toIso8601String();
                final productName = order['product_name'] ?? 'unknown';
                final price = order['price'] ?? 0.0;
                final qty = order['qty'] ?? 1;
                transactionId = '${timestamp}_${productName}_${price}_${qty}';
              }

              if (!finalGroupedOrders.containsKey(transactionId)) {
                finalGroupedOrders[transactionId] = [];
              }
              finalGroupedOrders[transactionId]!.add(order);
            }
          }

          print('Grouped orders: ${finalGroupedOrders.keys.length} groups');
          for (final entry in finalGroupedOrders.entries) {
            print('Group ${entry.key}: ${entry.value.length} items');
          }

          // Convert grouped orders to a list of combined orders
          final combinedOrders = finalGroupedOrders.entries.map((entry) {
            final orders = entry.value;
            final transactionId = entry.key;

            if (orders.length == 1) {
              // Single item order - return as is
              final order = orders.first;

              // Handle local orders with items array structure
              if (order.containsKey('items') &&
                  order['items'] is List &&
                  (order['items'] as List).isNotEmpty) {
                final items = order['items'] as List;
                final firstItem = items[0];

                // If there are multiple items, mark as multi-item order
                if (items.length > 1) {
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
                    'transaction_id': transactionId,
                  };
                } else {
                  return {
                    ...order,
                    'product_name':
                        firstItem['product_name'] ?? 'Unknown Product',
                    'product_img': firstItem['product_img'] ?? '',
                    'qty': firstItem['qty'] ?? 1,
                    'price': firstItem['price'] ?? 0.0,
                    'batch_no': firstItem['batch_no'] ?? '',
                    'transaction_id': transactionId,
                  };
                }
              }

              return {
                ...order,
                'transaction_id': transactionId,
              };
            } else {
              // Multi-item order - combine into one order
              final firstOrder = orders.first;
              final paymentMethod = firstOrder['payment_type'] ??
                  firstOrder['payment_method'] ??
                  '';
              final isCashOnDelivery = _isCashOnDelivery(paymentMethod);

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

                // Determine the most common payment method
                final paymentMethods = orders
                    .map((order) =>
                        order['payment_method'] ?? order['payment_type'] ?? '')
                    .where((method) => method.isNotEmpty)
                    .toList();

                String finalPaymentMethod = '';
                if (paymentMethods.isNotEmpty) {
                  // Use the most common payment method, or the first one if all are the same
                  final methodCounts = <String, int>{};
                  for (final method in paymentMethods) {
                    methodCounts[method] = (methodCounts[method] ?? 0) + 1;
                  }

                  final mostCommonMethod = methodCounts.entries
                      .reduce((a, b) => a.value > b.value ? a : b)
                      .key;

                  finalPaymentMethod = mostCommonMethod;
                }

                print(
                    'Combined order for ${transactionId}: ${orders.length} items, payment: $finalPaymentMethod');

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
                  'transaction_id': transactionId,
                  'payment_method': finalPaymentMethod,
                };
              } else if (isCashOnDelivery) {
                // Handle individual COD items that should be grouped
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

                // Determine the most common payment method
                final paymentMethods = orders
                    .map((order) =>
                        order['payment_method'] ?? order['payment_type'] ?? '')
                    .where((method) => method.isNotEmpty)
                    .toList();

                String finalPaymentMethod = '';
                if (paymentMethods.isNotEmpty) {
                  // Use the most common payment method, or the first one if all are the same
                  final methodCounts = <String, int>{};
                  for (final method in paymentMethods) {
                    methodCounts[method] = (methodCounts[method] ?? 0) + 1;
                  }

                  final mostCommonMethod = methodCounts.entries
                      .reduce((a, b) => a.value > b.value ? a : b)
                      .key;

                  finalPaymentMethod = mostCommonMethod;
                }

                print(
                    'Combined COD order for ${transactionId}: ${orders.length} items, payment: $finalPaymentMethod');

                return {
                  ...firstOrder,
                  'order_items': orderItems,
                  'qty': totalQuantity,
                  'total_price': totalAmount,
                  'is_multi_item': true,
                  'item_count': orders.length,
                  'transaction_id': transactionId,
                  'payment_method': finalPaymentMethod,
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

                // Determine the most common payment method
                final paymentMethods = orders
                    .map((order) =>
                        order['payment_method'] ?? order['payment_type'] ?? '')
                    .where((method) => method.isNotEmpty)
                    .toList();

                String finalPaymentMethod = '';
                if (paymentMethods.isNotEmpty) {
                  // Use the most common payment method, or the first one if all are the same
                  final methodCounts = <String, int>{};
                  for (final method in paymentMethods) {
                    methodCounts[method] = (methodCounts[method] ?? 0) + 1;
                  }

                  final mostCommonMethod = methodCounts.entries
                      .reduce((a, b) => a.value > b.value ? a : b)
                      .key;

                  finalPaymentMethod = mostCommonMethod;
                }

                print(
                    'Combined server order for ${transactionId}: ${orders.length} items, payment: $finalPaymentMethod');

                return {
                  ...firstOrder,
                  'order_items': orderItems,
                  'qty': totalQuantity,
                  'total_price': totalAmount,
                  'is_multi_item': true,
                  'item_count': orders.length,
                  'transaction_id': transactionId,
                  'payment_method': finalPaymentMethod,
                };
              }
            }
          }).toList();

          // Remove duplicates based on delivery_id and prefer orders with actual product data
          final uniqueOrders = <String, dynamic>{};
          for (final order in combinedOrders) {
            // For COD orders, use delivery_id as the primary key for deduplication
            final paymentMethod =
                order['payment_method'] ?? order['payment_type'] ?? '';
            final isCashOnDelivery = _isCashOnDelivery(paymentMethod);

            String baseTransactionId;
            if (isCashOnDelivery) {
              // For COD orders, prioritize delivery_id
              baseTransactionId = order['delivery_id'] ??
                  order['order_id'] ??
                  order['transaction_id'] ??
                  '';
            } else {
              // For non-COD orders, use delivery_id as primary key for deduplication
              final deliveryId = order['delivery_id'] ?? '';
              baseTransactionId = deliveryId.isNotEmpty
                  ? deliveryId
                  : (order['transaction_id'] ?? '');
            }

            if (!uniqueOrders.containsKey(baseTransactionId)) {
              uniqueOrders[baseTransactionId] = order;
              print(
                  'Added order: ${order['product_name']} with baseTransactionId: $baseTransactionId (COD: $isCashOnDelivery)');
            } else {
              // Check if we should replace the existing order
              final existingOrder = uniqueOrders[baseTransactionId];
              final existingStatus = existingOrder['status'] ?? '';
              final newStatus = order['status'] ?? '';

              // Prefer orders with actual product data and completed status
              final shouldReplace = _shouldReplaceOrderWithData(
                  existingOrder, order, existingStatus, newStatus);

              if (shouldReplace) {
                uniqueOrders[baseTransactionId] = order;
                print(
                    'Replaced order: ${existingOrder['product_name']} (${existingStatus}) with ${order['product_name']} (${newStatus})');
              } else {
                print(
                    'Keeping existing order: ${existingOrder['product_name']} (${existingStatus}) over ${order['product_name']} (${newStatus})');
              }
            }
          }

          print('Final orders count: ${uniqueOrders.length}');

          // Log final orders for debugging
          print('=== FINAL ORDERS ===');
          for (final entry in uniqueOrders.entries) {
            final order = entry.value;
            print('Base ID: ${entry.key}');
            print('  Product: ${order['product_name']}');
            print('  Status: ${order['status']}');
            print(
                '  Payment: ${order['payment_method'] ?? order['payment_type']}');
            print('  Transaction ID: ${order['transaction_id']}');
            print('  ---');
          }

          setState(() {
            _orders = uniqueOrders.values.toList();
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
    if (url == null || url.isEmpty || url == 'default_product.png') {
      return '';
    }

    if (url.startsWith('http')) {
      return url;
    }

    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }

    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }

    // For relative paths (like _1750059953_Gastrone-original-200ml.png)
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
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
                placeholder: (context, url) =>
                    Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Icon(Icons.broken_image),
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
    final paymentMethod =
        order['payment_method'] ?? order['payment_type'] ?? '';

    // Improved payment method detection
    final isCashOnDelivery = _isCashOnDelivery(paymentMethod);

    // For multi-item orders, show first item as representative
    final productName = isMultiItem
        ? '${order['product_name'] ?? 'Unknown Product'} + ${itemCount - 1} more items'
        : order['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(order['product_img']);
    final qty = order['qty'] ?? 1;
    final total = order['total_price'] ?? 0.0;
    final status = order['status'] ?? 'Processing';
    final transactionId = order['transaction_id']?.toString() ?? '';
    final isExpanded = _expandedOrders.contains(transactionId);
    List<dynamic> orderItems = [];
    if (isMultiItem) {
      if (order['order_items'] is List && (order['order_items'] as List).isNotEmpty) {
        orderItems = order['order_items'];
      } else if (order['items'] is List && (order['items'] as List).isNotEmpty) {
        orderItems = order['items'];
      }
    }

    print(
        'Building card for: $productName, payment: $paymentMethod, isCOD: $isCashOnDelivery');

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
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
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: productImg.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: productImg,
                                fit: BoxFit.cover,
                                width: 70,
                                height: 70,
                                placeholder: (context, url) =>
                                    Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.broken_image),
                              )
                            : Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.grey,
                                  size: 24,
                                ),
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
                        if (isMultiItem)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                              label: Text(isExpanded ? 'Hide Items' : 'View Items'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size(60, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedOrders.remove(transactionId);
                                  } else {
                                    _expandedOrders.add(transactionId);
                                  }
                                });
                              },
                            ),
                          ),
                        if (isMultiItem && isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: orderItems.isNotEmpty
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: orderItems.map<Widget>((item) {
                                      final name = item['product_name'] ?? item['name'] ?? 'Unknown Product';
                                      final qty = item['qty'] ?? item['quantity'] ?? 1;
                                      final price = item['price'] ?? 0.0;
                                      final imgUrl = getImageUrl(item['product_img'] ?? item['image']);
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: imgUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: imgUrl,
                                                      width: 36,
                                                      height: 36,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                                                      errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 18, color: Colors.grey[400]),
                                                    )
                                                  : Container(
                                                      width: 36,
                                                      height: 36,
                                                      color: Colors.grey[200],
                                                      child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 18),
                                                    ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: TextStyle(fontSize: 13, color: Colors.black87),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              'x$qty',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'GHS ${(price * (qty is num ? qty : 1)).toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'No items found in this order.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
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

  // Helper method to properly detect Cash on Delivery
  bool _isCashOnDelivery(String paymentMethod) {
    if (paymentMethod.isEmpty) return false;

    final method = paymentMethod.toLowerCase().trim();

    // Check for various COD variations
    return method.contains('cash on delivery') ||
        method.contains('cod') ||
        method.contains('cash') ||
        method.contains('delivery') ||
        method == 'cash_on_delivery' ||
        method == 'cash on delivery';
  }

  // Helper method to validate order data
  bool _isValidOrder(dynamic order) {
    if (order == null) return false;

    // Check if order has at least one required field
    final hasProductName = order['product_name'] != null &&
        order['product_name'].toString().isNotEmpty;
    final hasItems = order['items'] != null &&
        order['items'] is List &&
        (order['items'] as List).isNotEmpty;
    final hasCreatedAt = order['created_at'] != null;

    return hasProductName || hasItems || hasCreatedAt;
  }

  // Helper method to determine which order to keep when there are duplicates
  bool _shouldReplaceOrderWithData(dynamic existingOrder, dynamic newOrder,
      String existingStatus, String newStatus) {
    // First priority: prefer orders with actual product data over null/empty product names
    final existingHasProduct = existingOrder['product_name'] != null &&
        existingOrder['product_name'].toString().isNotEmpty;
    final newHasProduct = newOrder['product_name'] != null &&
        newOrder['product_name'].toString().isNotEmpty;

    // If new order has product data and existing doesn't, always prefer new
    if (newHasProduct && !existingHasProduct) {
      return true;
    }

    // If existing order has product data and new doesn't, keep existing
    if (existingHasProduct && !newHasProduct) {
      return false;
    }

    // If both have product data or both don't, then use status priority
    final statusPriority = ['cancelled', 'pending', 'processing', 'completed'];

    final existingIndex = statusPriority
        .indexWhere((status) => existingStatus.toLowerCase().contains(status));
    final newIndex = statusPriority
        .indexWhere((status) => newStatus.toLowerCase().contains(status));

    // If new status has higher priority, replace the existing order
    if (newIndex > existingIndex) {
      return true;
    }

    return false;
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
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(_orders[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.15),
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
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _orders.isEmpty
                  ? _buildEmptyState()
                  : _buildOrderList(),
      bottomNavigationBar: CustomBottomNav(initialIndex: 0),
    );
  }
}
