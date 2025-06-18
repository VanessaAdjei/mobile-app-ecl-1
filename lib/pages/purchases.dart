// pages/purchases.dart
import 'package:eclapp/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      if (result['status'] == 'success' && result['data'] is List) {
        if (mounted) {
          setState(() {
            _orders = result['data'];
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
    final productName = order['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(order['product_img']);
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingPage(
                orderDetails: order,
              ),
            ),
          );
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
                    onTap: () => _showFullImageDialog(productImg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error_outline,
                              color: Colors.red),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: $qty',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GHS ${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, thickness: 1.1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: GHS ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
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
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? Colors.green.shade700,
        elevation: theme.appBarTheme.elevation ?? 0,
        centerTitle: theme.appBarTheme.centerTitle ?? true,
        leading: AppBackButton(
          backgroundColor: theme.primaryColor,
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
          style: theme.appBarTheme.titleTextStyle ??
              const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchOrders,
            tooltip: 'Refresh',
          ),
          CartIconButton(
            iconColor: Colors.white,
            iconSize: 24,
            backgroundColor: Colors.transparent,
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
    );
  }
}
