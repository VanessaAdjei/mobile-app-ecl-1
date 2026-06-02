// pages/purchases.dart
import 'dart:async';
import 'package:eclapp/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'bottomnav.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../config/app_colors.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/order_history_transformer.dart';
import '../services/background_order_checker.dart';
import '../widgets/cart_icon_button.dart';
import '../utils/app_error_utils.dart';
import '../widgets/error_display.dart';
import 'order_tracking_page.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  PurchaseScreenState createState() => PurchaseScreenState();
}

class PurchaseScreenState extends State<PurchaseScreen> {
  final Set<String> _expandedOrders = {};
  bool _isLoading = true;
  String? _error;
  List<dynamic> _orders = [];
  final ScrollController _scrollController = ScrollController();

  // pagination stuff
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  // cache orders so we dont have to load them every time
  static List<dynamic>? _cachedOrders;
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadOrders() async {
    debugPrint('🔍 Loading orders...');
    // check if we have cached data that's still good
    if (_cachedOrders != null && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      final isCacheValid = timeSinceLastFetch < _cacheValidDuration;
      debugPrint(
          '🔍 Cache check: ${isCacheValid ? 'HIT' : 'MISS'} (age: ${timeSinceLastFetch.inMinutes}min)');

      if (isCacheValid && _cachedOrders!.isNotEmpty) {
        setState(() {
          _orders = _cachedOrders!;
          _isLoading = false;
        });
        debugPrint('🔍 Loaded ${_orders.length} orders from cache');
        return;
      } else if (isCacheValid && _cachedOrders!.isEmpty) {
        // Cache has 0 orders - this might be stale, force refresh
        debugPrint('🔍 Cache has 0 orders, forcing fresh fetch...');
        _cachedOrders = null;
        _lastFetchTime = null;
      }
    }

    await _fetchOrders();
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
      debugPrint('🔍 Orders API result status: ${result['status']}');
      debugPrint(
          '🔍 Orders API result data type: ${result['data'].runtimeType}');
      debugPrint(
          '🔍 Orders API result data length: ${result['data'] is List ? (result['data'] as List).length : 'N/A'}');

      if (result['status'] == 'success' && result['data'] is List) {
        if (mounted) {
          final rawOrders = result['data'] as List;
          debugPrint(
              '🔍 Raw orders count before processing: ${rawOrders.length}');
          if (rawOrders.isNotEmpty) {
            debugPrint(
                '🔍 Sample raw order: ${rawOrders.first.toString().substring(0, rawOrders.first.toString().length > 300 ? 300 : rawOrders.first.toString().length)}');
          }
          final processedOrders = await _processOrders(rawOrders);
          debugPrint('🔍 Processed orders count: ${processedOrders.length}');

          // save the data to cache
          _cachedOrders = processedOrders;
          _lastFetchTime = DateTime.now();

          setState(() {
            _orders = processedOrders;
            _isLoading = false;
            // refresh done
            _hasMoreData = processedOrders.length >= _pageSize;
          });

          // Trigger order status check for notifications (runs in background)
          unawaited(BackgroundOrderChecker.checkNow());
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to load orders');
      }
    } catch (e, st) {
      AppErrorUtils.log('PurchaseScreen._fetchOrders', e, st);
      if (mounted) {
        setState(() {
          _error = AppErrorUtils.userMessage(
            e,
            fallback: 'Could not load your orders',
          );
          _isLoading = false;
          // Refresh completed
        });
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    // simulate pagination (in real app you'd pass page number to api)
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoadingMore = false;
      _hasMoreData = false; // For demo, assume no more data
    });
  }

  Future<void> _refreshOrders() async {
    debugPrint('🔍 Refreshing orders - clearing cache...');
    setState(() {
      // refresh started
    });

    // Clear cache to force fresh data
    _cachedOrders = null;
    _lastFetchTime = null;

    await _fetchOrders();
  }

  Future<List<dynamic>> _processOrders(List<dynamic> rawOrders) async {
    debugPrint('🔍 Processing ${rawOrders.length} orders...');
    // process orders in a separate isolate to make it faster
    return await _processOrdersInBackground(rawOrders);
  }

  Future<List<dynamic>> _processOrdersInBackground(
      List<dynamic> rawOrders) async {
    return List<dynamic>.from(
      OrderHistoryTransformer.processRawOrders(rawOrders),
    );
  }

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty || url == 'default_product.png') {
      return '';
    }

    return ApiConfig.getImageOrStorageUrl(url);
  }

  // Page surface (aligned with profile / policy screens)
  static const Color _pageBgLight = Color(0xFFE5EDE8);
  static const Color _pageBgDark = Color(0xFF121212);
  static const Color _bodyTextLight = Color(0xFF374151);

  Color _statusPillBackground(String status, bool isDark) {
    final s = status.toLowerCase();
    if (s.contains('cancel') ||
        s.contains('declin') ||
        s.contains('fail') ||
        s.contains('reject')) {
      return isDark ? const Color(0xFF3B1C1C) : Colors.red.shade50;
    }
    if (s == 'completed' || s == 'paid' || s.contains('deliver')) {
      return isDark
          ? AppColors.accent.withValues(alpha: 0.22)
          : const Color(0xFFE8F5E9);
    }
    if (s.contains('process') || s.contains('confirm') || s.contains('ship')) {
      return isDark
          ? Colors.blue.shade900.withValues(alpha: 0.35)
          : Colors.blue.shade50;
    }
    if (s.contains('pending')) {
      return isDark
          ? Colors.orange.shade900.withValues(alpha: 0.35)
          : Colors.amber.shade50;
    }
    return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
  }

  Color _statusPillForeground(String status, bool isDark) {
    final s = status.toLowerCase();
    if (s.contains('cancel') ||
        s.contains('declin') ||
        s.contains('fail') ||
        s.contains('reject')) {
      return isDark ? Colors.red.shade200 : Colors.red.shade700;
    }
    if (s == 'completed' || s == 'paid' || s.contains('deliver')) {
      return isDark ? const Color(0xFF81C784) : AppColors.accent;
    }
    if (s.contains('process') || s.contains('confirm') || s.contains('ship')) {
      return isDark ? Colors.blue.shade200 : Colors.blue.shade800;
    }
    if (s.contains('pending')) {
      return isDark ? Colors.orange.shade200 : Colors.orange.shade900;
    }
    return isDark ? Colors.grey.shade300 : Colors.grey.shade700;
  }

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : const Color(0xFFDCE5DF);

    final orderDate = DateTime.tryParse(order['created_at'] ?? '');
    final isMultiItem = order['is_multi_item'] == true;
    final itemCount = order['item_count'] ?? 1;
    final paymentMethod =
        order['payment_method'] ?? order['payment_type'] ?? '';
    final isCashOnDelivery =
        OrderHistoryTransformer.isCashOnDelivery(paymentMethod);

    final productName = isMultiItem
        ? '${order['product_name'] ?? 'Unknown Product'} + ${itemCount - 1} more items'
        : order['product_name'] ?? 'Unknown Product';
    final productImg = getImageUrl(order['product_img']);
    final qty = (order['qty'] ?? 1).toInt();
    final total = (order['total_price'] ?? 0.0).toDouble();
    final status = order['status'] ?? 'Processing';
    final transactionId = order['transaction_id']?.toString() ?? '';
    final isExpanded = _expandedOrders.contains(transactionId);
    final isDeclined = _isOrderDeclined(status);

    List<dynamic> orderItems = [];
    if (isMultiItem) {
      if (order['order_items'] is List &&
          (order['order_items'] as List).isNotEmpty) {
        orderItems = order['order_items'] ?? [];
      } else if (order['items'] is List &&
          (order['items'] as List).isNotEmpty) {
        orderItems = order['items'] ?? [];
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isDeclined ? null : () => _navigateToOrderTracking(order),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(orderDate, isMultiItem, itemCount,
                      isCashOnDelivery, status, isDark),
                  const SizedBox(height: 10),
                  _buildOrderContent(
                      productImg,
                      productName,
                      qty,
                      order,
                      isCashOnDelivery,
                      total,
                      isMultiItem,
                      transactionId,
                      isExpanded,
                      orderItems,
                      isDark),
                  if (isDeclined) _buildDeclinedOrderMessage(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(DateTime? orderDate, bool isMultiItem, int itemCount,
      bool isCashOnDelivery, String status, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 13,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            orderDate != null
                ? DateFormat('MMM dd, yyyy').format(orderDate)
                : 'Date unavailable',
            style: GoogleFonts.poppins(
              color: isDark ? Colors.grey.shade400 : _bodyTextLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMultiItem) ...[
          Container(
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.shade900.withValues(alpha: 0.35)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$itemCount items',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (isCashOnDelivery) ...[
          Container(
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.shade900.withValues(alpha: 0.35)
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'COD',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        Container(
          constraints: const BoxConstraints(maxWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusPillBackground(status, isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            status,
            style: GoogleFonts.poppins(
              color: _statusPillForeground(status, isDark),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderContent(
      String productImg,
      String productName,
      int qty,
      dynamic order,
      bool isCashOnDelivery,
      double total,
      bool isMultiItem,
      String transactionId,
      bool isExpanded,
      List<dynamic> orderItems,
      bool isDark) {
    final titleColor = isDark ? Colors.white : Colors.black87;
    final metaColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildProductImage(productImg, isDark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  height: 1.22,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Qty: $qty',
                style: GoogleFonts.poppins(
                  color: metaColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Order ID: ${order['delivery_id'] ?? order['order_id'] ?? 'N/A'}',
                style: GoogleFonts.poppins(
                  color: metaColor,
                  fontSize: 11,
                ),
              ),
              if (isCashOnDelivery) ...[
                const SizedBox(height: 3),
                Text(
                  'Cash on Delivery',
                  style: GoogleFonts.poppins(
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'GHS ${total.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (isMultiItem) _buildExpandButton(transactionId, isExpanded),
              if (isMultiItem && isExpanded)
                _buildOrderItems(orderItems, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(String productImg, bool isDark) {
    final placeholderBg =
        isDark ? Colors.grey.shade800 : const Color(0xFFF0F4F1);
    return GestureDetector(
      onTap: () =>
          productImg.isNotEmpty ? _showFullImageDialog(productImg) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : const Color(0xFFE2E8E0),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 62,
            height: 62,
            child: productImg.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: productImg,
                    fit: BoxFit.cover,
                    width: 62,
                    height: 62,
                    placeholder: (context, url) => Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade500,
                      size: 22,
                    ),
                  )
                : ColoredBox(
                    color: placeholderBg,
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandButton(String transactionId, bool isExpanded) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: AppColors.primary,
        ),
        label: Text(
          isExpanded ? 'Hide items' : 'View items',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(56, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.primary,
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
    );
  }

  Widget _buildOrderItems(List<dynamic> orderItems, bool isDark) {
    final insetBg = isDark
        ? Colors.grey.shade900.withValues(alpha: 0.5)
        : const Color(0xFFF4F7F5);
    final lineColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: insetBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8E0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: orderItems.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: orderItems.map<Widget>((item) {
                    final name = item['product_name'] ??
                        item['name'] ??
                        'Unknown Product';
                    final qty = item['qty'] ?? item['quantity'] ?? 1;
                    final price = item['price'] ?? 0.0;
                    final imgUrl =
                        getImageUrl(item['product_img'] ?? item['image']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                        child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))),
                                    errorWidget: (context, url, error) => Icon(
                                        Icons.broken_image_outlined,
                                        size: 16,
                                        color: Colors.grey.shade500),
                                  )
                                : Container(
                                    width: 34,
                                    height: 34,
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    child: Icon(Icons.inventory_2_outlined,
                                        color: Colors.grey.shade500, size: 16),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '×$qty',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: lineColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GHS ${(price * (qty is num ? qty : 1)).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'No items found in this order.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: lineColor,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDeclinedOrderMessage(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.red.shade900.withValues(alpha: 0.25)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: isDark ? Colors.red.shade300 : Colors.red.shade600,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Order not placed, payment failed',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.red.shade200 : Colors.red.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToOrderTracking(dynamic order) {
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
          title: const Text('Error'),
          content: const Text('Order data is invalid. Please contact support.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  bool _isOrderDeclined(String status) {
    final lowerStatus = status.toLowerCase();
    return lowerStatus.contains('declined') ||
        lowerStatus.contains('failed') ||
        lowerStatus.contains('cancelled') ||
        lowerStatus.contains('rejected');
  }

  Widget _buildSkeletonOrderCard(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : const Color(0xFFDCE5DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 12,
                width: 88,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                height: 22,
                width: 64,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 72,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        child: Column(
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _buildSkeletonOrderCard(isDark),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _ordersBodySlivers() {
    if (_isLoading) {
      return [
        SliverToBoxAdapter(child: _buildLoadingSkeleton()),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorDisplay(
            title: 'Could not load orders',
            message: _error ?? 'An error occurred while loading your orders',
            showRetry: true,
            onRetry: _refreshOrders,
          ),
        ),
      ];
    }
    if (_orders.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _orders.length) {
                return _buildLoadMoreIndicator();
              }
              return _buildOrderCard(_orders[index]);
            },
            childCount: _orders.length + (_hasMoreData ? 1 : 0),
          ),
        ),
      ),
    ];
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.accent;
    final subtitleColor = isDark ? Colors.grey.shade400 : _bodyTextLight;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : const Color(0xFFDFF5E8),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 56,
                  color: isDark ? Colors.green.shade300 : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No orders yet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Start shopping to see your orders here',
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.45,
                color: subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Profile(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Shop now',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMoreData) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Center(
        child: _isLoadingMore
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.9 : 1),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? _pageBgDark : _pageBgLight;

    return Scaffold(
      backgroundColor: pageBg,
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            EclExpandableSliverAppBar(
              toolbarTitle: 'Your Orders',
              heroTitle: 'Your Orders',
              heroSubtitle: 'Track your purchase history',
              onBack: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Profile(),
                  ),
                );
              },
              actions: [
                CartIconButton(
                  iconColor: Colors.white,
                  iconSize: 22,
                  backgroundColor: Colors.transparent,
                ),
              ],
            ),
            ..._ordersBodySlivers(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 0),
    );
  }
}
