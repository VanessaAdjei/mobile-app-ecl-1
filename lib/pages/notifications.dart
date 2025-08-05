// pages/notifications.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'notification_provider.dart';
import 'order_tracking_page.dart';
import 'app_back_button.dart';
import '../services/order_notification_service.dart';
import '../services/performance_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, List<Map<String, dynamic>>> groupedNotifications = {};
  bool isLoading = true;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, DateTime> _lastRefreshTimes = {};

  final Map<String, bool> _expandedGroups = {};
  final Map<String, List<Map<String, dynamic>>> _cachedNotifications = {};
  bool _isDisposed = false;

  final PerformanceService _performanceService = PerformanceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });

    _scrollController.addListener(_onScroll);

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Implement lazy loading if needed
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more notifications if needed
    }
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool forceRefresh = false}) async {
    if (_isDisposed) return;

    _performanceService.startTimer('notifications_loading');

    // Force refresh unread count when loading notifications
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.refreshUnreadCount();
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }

    try {
      // Check if we need to refresh (avoid unnecessary API calls)
      if (!forceRefresh && groupedNotifications.isNotEmpty) {
        final lastRefresh = _lastRefreshTimes['notifications'];
        if (lastRefresh != null &&
            DateTime.now().difference(lastRefresh).inMinutes < 5) {
          debugPrint('📱 Using cached notifications');
          return;
        }
      }

      setState(() {
        _isRefreshing = true;
      });

      // Get notifications from the new service with timeout
      final notifications = await OrderNotificationService.getNotifications()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('📱 Notification loading timed out, using empty list');
        return [];
      });

      if (_isDisposed) return;

      // Clear existing data
      groupedNotifications.clear();

      // Group notifications by date with optimized processing
      final Map<String, List<Map<String, dynamic>>> tempGroups = {};

      for (final notification in notifications) {
        try {
          final timestamp = DateTime.parse(notification['timestamp']);
          final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

          tempGroups.putIfAbsent(dateKey, () => []).add(notification);
        } catch (e) {
          debugPrint('📱 Error processing notification: $e');
          continue;
        }
      }

      // Sort notifications within each group by timestamp (newest first)
      for (final key in tempGroups.keys) {
        tempGroups[key]!.sort((a, b) {
          try {
            final aTime = DateTime.parse(a['timestamp']);
            final bTime = DateTime.parse(b['timestamp']);
            return bTime.compareTo(aTime);
          } catch (e) {
            return 0;
          }
        });
      }

      // Update the main grouped notifications
      groupedNotifications.addAll(tempGroups);
      _lastRefreshTimes['notifications'] = DateTime.now();

      // Don't automatically mark all notifications as read when viewing
      // Users should manually mark them as read by tapping on them
      if (mounted) {
        final notificationProvider =
            Provider.of<NotificationProvider>(context, listen: false);
        await notificationProvider.refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _isRefreshing = false;
        });
      }
      _performanceService.stopTimer('notifications_loading');
    }
  }

  // Helper method to convert string values to boolean
  bool _convertToBoolean(dynamic value) {
    if (value is bool) {
      return value;
    } else if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  Future<void> _saveNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Clear existing notification keys to prevent duplicates
      Set<String> keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('notification_')) {
          await prefs.remove(key);
        }
      }

      // Save current notifications
      await Future.forEach(groupedNotifications.entries, (entry) async {
        String date = entry.key;
        List<Map<String, dynamic>> notifications = entry.value;
        List<String> notificationStrings =
            notifications.map((notif) => jsonEncode(notif)).toList();
        await prefs.setStringList('notification_$date', notificationStrings);
      });
    } catch (e) {
      // Silently handle saving errors
    }
  }

  void _toggleExpand(String group, int index) {
    setState(() {
      final key = '$group-$index';
      _expandedGroups[key] = !(_expandedGroups[key] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              // Enhanced header with better design
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade700,
                        Colors.green.shade800,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          AppBackButton(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Stay updated with your orders',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Notifications content
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : groupedNotifications.isEmpty
                        ? _buildEmptyState()
                        : _buildNotificationsList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see order updates and promotions here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final sortedDates = groupedNotifications.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(forceRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final notifications = groupedNotifications[dateKey] ?? [];

          return _buildNotificationGroup(dateKey, notifications, index);
        },
      ),
    );
  }

  Widget _buildNotificationGroup(String dateKey,
      List<Map<String, dynamic>> notifications, int groupIndex) {
    final theme = Theme.of(context);

    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: (groupIndex * 80).ms),
        SlideEffect(
          duration: 400.ms,
          begin: const Offset(0, 0.1),
          end: Offset.zero,
          delay: (groupIndex * 80).ms,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Text(
              _formatDate(dateKey),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),

          // Notifications for this date
          ...notifications.asMap().entries.map((entry) {
            final index = entry.key;
            final notification = entry.value;
            return _buildNotificationCard(notification, index);
          }),
        ],
      ),
    );
  }

  String _formatDate(String dateKey) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    try {
      final date = DateTime.parse(dateKey);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Today';
      } else if (dateOnly == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('EEEE, MMMM d').format(date);
      }
    } catch (e) {
      return dateKey;
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final isRead = _convertToBoolean(notification['is_read']);
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);

    // Format timestamp
    String timeText = '';
    try {
      final timestamp = DateTime.parse(notification['timestamp']);
      timeText = DateFormat('h:mm a').format(timestamp);
    } catch (e) {
      timeText = 'Just now';
    }

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_sweep, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(_getDateKey(notification), index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showNotificationDetails(notification),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification icon
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          iconData,
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      if (!isRead)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Notification content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  fontSize: 16,
                                  color: isRead
                                      ? Colors.grey[600]
                                      : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['message'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getActionText(notification['icon']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getDateKey(Map<String, dynamic> notification) {
    try {
      final timestamp = DateTime.parse(notification['timestamp']);
      return DateFormat('yyyy-MM-dd').format(timestamp);
    } catch (e) {
      return 'unknown';
    }
  }

  void _deleteNotification(String group, int index) {
    setState(() {
      groupedNotifications[group]?.removeAt(index);
      if (groupedNotifications[group]?.isEmpty ?? false) {
        groupedNotifications.remove(group);
      }
    });
    _saveNotifications();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getActionText(String? iconType) {
    return 'Track Order';
  }

  void _handleNotificationAction(Map<String, dynamic> notification) {
    final orderId = notification['order_id']?.toString() ?? '';
    final orderNumber = notification['order_number']?.toString() ?? '';

    debugPrint('📱 Action button tapped - navigating to tracking');
    debugPrint('📱 Order ID: $orderId');
    debugPrint('📱 Order Number: $orderNumber');

    Navigator.pop(context);

    // Create order details map for tracking page
    final items = notification['items'] ?? [];
    final mappedItems = items
        .map((item) => {
              'product_name': item['name'] ?? 'Unknown Product',
              'product_img': item['imageUrl'] ??
                  item['image'] ??
                  item['product_img'] ??
                  '',
              'qty': item['quantity'] ?? 1,
              'price': (item['price'] ?? 0.0).toDouble(),
              'batch_no': item['batchNo'] ?? '',
            })
        .toList();

    final orderDetails = {
      'id': orderId,
      'order_number': orderNumber,
      'total_amount': notification['total_amount'],
      'order_items': mappedItems, // Use the correct field name
      'status': notification['status'] ?? 'pending',
      'created_at': notification['timestamp'],
    };

    debugPrint('📱 Navigating to OrderTrackingPage...');
    debugPrint('📱 Order details: $orderDetails');

    // Navigate to order tracking page
    try {
      debugPrint('📱 About to navigate to OrderTrackingPage');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            orderDetails: orderDetails,
          ),
        ),
      );
      debugPrint('📱 Navigation successful!');
    } catch (e) {
      debugPrint('📱 Navigation error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navigating to tracking page: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin:
              EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 100),
        ),
      );

      try {
        Navigator.pushNamed(context, '/purchases');
      } catch (fallbackError) {
        debugPrint('📱 Fallback navigation also failed: $fallbackError');
      }
    }
  }

 
  Widget _buildColorfulMainIcon(String? iconType) {
    switch (iconType) {
      case 'product':
        return Icon(
          Icons.shopping_cart,
          color: Colors.orange.shade600,
          size: 24,
        );
      case 'confirmation':
        return Icon(
          Icons.receipt,
          color: Colors.green.shade600,
          size: 24,
        );
      case 'shipping':
        return Icon(
          Icons.local_shipping,
          color: Colors.blue.shade600,
          size: 24,
        );
      case 'delivered':
        return Icon(
          Icons.star,
          color: Colors.purple.shade600,
          size: 24,
        );
      default:
        return Icon(
          Icons.notifications,
          color: Colors.grey.shade600,
          size: 24,
        );
    }
  }

  /// Build enhanced item card with modern design
  Widget _buildEnhancedItemCard(Map<String, dynamic> item) {
    final itemName = item['name']?.toString() ??
        item['product_name']?.toString() ??
        'Unknown Item';
    final quantity = item['quantity']?.toString() ?? '1';
    final price =
        item['price']?.toString() ?? item['total_price']?.toString() ?? '0.00';
    final rawImageUrl = item['image']?.toString() ??
        item['product_image']?.toString() ??
        item['image_url']?.toString() ??
        item['product_image_url']?.toString() ??
        item['imageUrl']?.toString() ??
        '';

    final imageUrl = _getImageUrl(rawImageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image with enhanced styling
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 140,
                      memCacheHeight: 140,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.image,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.inventory,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Item details with enhanced styling
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'GHS $price',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build item card with image and details
  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemName = item['name']?.toString() ??
        item['product_name']?.toString() ??
        'Unknown Item';
    final quantity = item['quantity']?.toString() ?? '1';
    final price =
        item['price']?.toString() ?? item['total_price']?.toString() ?? '0.00';
    final rawImageUrl = item['image']?.toString() ??
        item['product_image']?.toString() ??
        item['image_url']?.toString() ??
        item['product_image_url']?.toString() ??
        item['imageUrl']?.toString() ??
        '';

    final imageUrl = _getImageUrl(rawImageUrl);

    // Debug logging
    debugPrint('📱 Building item card for: $itemName');
    debugPrint('📱 Item data: $item');
    debugPrint('📱 Raw image URL: $rawImageUrl');
    debugPrint('📱 Processed image URL: $imageUrl');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    memCacheWidth: 120,
                    memCacheHeight: 120,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.image,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.inventory,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Qty: $quantity',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'GHS $price',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get image URL with proper formatting
  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    // Otherwise, treat as filename
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  }

  void _debugStorage() async {
    try {
      final notifications = await OrderNotificationService.getNotifications();
      final unreadCount = await OrderNotificationService.getUnreadCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Storage Debug: ${notifications.length} total, $unreadCount unread'),
            duration: const Duration(seconds: 4),
          ),
        );

        // Also print to console for detailed debugging
        debugPrint(
            '📱 Storage Debug: ${notifications.length} total notifications');
        debugPrint('📱 Storage Debug: $unreadCount unread notifications');
        for (int i = 0; i < notifications.length && i < 3; i++) {
          debugPrint('📱 Notification ${i + 1}: ${notifications[i]}');
        }
      }
    } catch (e) {
      debugPrint('Error debugging storage: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read
    final notificationId = notification['id']?.toString() ?? '';
    if (notificationId.isNotEmpty) {
      OrderNotificationService.markAsRead(notificationId);
    }

    // Show notification details
    _showNotificationDetails(notification);
  }

  Future<void> _markNotificationAsRead(
      Map<String, dynamic> notification) async {
    final notificationId = notification['id'].toString();

    try {
      // Use the proper service method to mark as read
      await OrderNotificationService.markAsRead(notificationId);

      // Update local state
      final dateKey = _getDateKey(notification);
      if (groupedNotifications.containsKey(dateKey)) {
        final notifications = groupedNotifications[dateKey]!;
        for (int i = 0; i < notifications.length; i++) {
          if (notifications[i]['id'] == notification['id']) {
            notifications[i]['is_read'] = true;

            setState(() {
              groupedNotifications[dateKey] = notifications;
            });
            break;
          }
        }
      }

      // Update unread count
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.refreshUnreadCount();
    } catch (e) {
      debugPrint('📱 Error marking notification as read: $e');
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    // Don't mark as read immediately - only when dialog is closed

    final items = notification['items'] ?? [];
    final orderNumber = notification['order_number']?.toString() ?? '';
    final totalAmount = notification['total_amount']?.toString() ?? '0.00';
    final status = notification['status']?.toString() ?? 'Order Placed';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          // Mark notification as read when dialog is dismissed
          await _markNotificationAsRead(notification);
          return true;
        },
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getNotificationIcon(notification),
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['title'] ?? 'Notification',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          // Mark notification as read when dialog is closed
                          await _markNotificationAsRead(notification);
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message
                        if (notification['message']?.toString().isNotEmpty ==
                            true) ...[
                          Text(
                            notification['message'] ?? '',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Items with images
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...items
                              .map((item) => _buildImageItemRow(item))
                              .toList(),
                          const SizedBox(height: 16),
                        ],

                        // Order details (just ID and amount)
                        if (orderNumber.isNotEmpty ||
                            totalAmount.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order Number',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        orderNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '$totalAmount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.green.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _handleNotificationAction(notification);
                                },
                                icon: const Icon(Icons.track_changes, size: 18),
                                label: const Text('Track Order'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  /// Build image item row - just images
  Widget _buildImageItemRow(Map<String, dynamic> item) {
    final rawImageUrl = item['image']?.toString() ??
        item['product_image']?.toString() ??
        item['image_url']?.toString() ??
        item['product_image_url']?.toString() ??
        item['imageUrl']?.toString() ??
        '';

    final imageUrl = _getImageUrl(rawImageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                height: 80,
                width: 80,
                memCacheWidth: 160,
                memCacheHeight: 160,
                placeholder: (context, url) => Container(
                  height: 80,
                  width: 80,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 80,
                  width: 80,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
              )
            : Container(
                height: 80,
                width: 80,
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.inventory,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ),
      ),
    );
  }

  IconData _getNotificationIcon(Map<String, dynamic> notification) {
    final iconType = notification['icon']?.toString() ?? '';
    switch (iconType) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'receipt':
        return Icons.receipt;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'star':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(Map<String, dynamic> notification) {
    final colorType = notification['color']?.toString() ?? '';
    switch (colorType) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
