// pages/notifications.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../providers/notification_provider.dart';
import 'order_tracking_page.dart';
import 'app_back_button.dart';
import '../services/order_notification_service.dart';
import '../services/performance_service.dart';

class NotificationsScreen extends StatefulWidget {
  final bool scrollToTop;

  const NotificationsScreen({super.key, this.scrollToTop = false});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, List<Map<String, dynamic>>> groupedNotifications = {};
  bool isLoading = true;

  final ScrollController _scrollController = ScrollController();
  final Map<String, DateTime> _lastRefreshTimes = {};

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
    // lazy loading if we need it
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // load more notifications if we need them
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

    // force refresh unread count when loading notifications
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
        // refresh started
      });

      // Get notifications from the new service with timeout
      final notifications = await OrderNotificationService.getNotifications()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('📱 Notification loading timed out, using empty list');
        return [];
      });

      if (_isDisposed) return;

      // clear existing data
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

      // sort notifications in each group by timestamp (newest first)
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

      // update the main grouped notifications
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
        });

        // Scroll to top if requested (e.g., when coming from notification banner)
        if (widget.scrollToTop && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
      _performanceService.stopTimer('notifications_loading');
    }
  }

  // convert string values to boolean
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

      // clear existing notification keys so we dont get duplicates
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
      // handle saving errors quietly
    }
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
              // nice header
              Animate(
                effects: [
                  FadeEffect(duration: 400.ms),
                  SlideEffect(
                      duration: 400.ms,
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0))
                ],
                child: Container(
                  padding: EdgeInsets.only(top: topPadding * 0.5),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see order updates and promotions here when they arrive',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    final sortedDates = groupedNotifications.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(forceRefresh: true),
      color: Colors.green.shade600,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // date header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
          child: Text(
            _formatDate(dateKey),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
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

    // format the timestamp
    String timeText = '';
    try {
      final timestamp = DateTime.parse(notification['timestamp']);
      timeText = DateFormat('h:mm a').format(timestamp);
    } catch (e) {
      timeText = 'Just now';
    }

    return Dismissible(
      key: Key('notification_${notification['id']}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (direction) {
        _deleteNotification(_getDateKey(notification), index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.grey.shade200 : Colors.blue.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isRead ? 0.02 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showNotificationDetails(notification),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // notification content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  fontSize: 15,
                                  color: isRead
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if ((notification['message'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notification['message'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade600.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _handleNotificationAction(
      Map<String, dynamic> notification) async {
    debugPrint('🔍 _handleNotificationAction called');
    debugPrint('🔍 Full notification: $notification');

    final orderId = notification['order_id']?.toString() ?? '';
    final orderNumber = notification['order_number']?.toString() ?? '';

    debugPrint('📱 Action button tapped - navigating to tracking');
    debugPrint('📱 Order ID: $orderId');
    debugPrint('📱 Order Number: $orderNumber');

    // Check if we have the required data
    if (orderId.isEmpty && orderNumber.isEmpty) {
      debugPrint('📱 No order ID or order number found in notification');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No order information found in this notification'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // make order details map for the tracking page
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

    Map<String, dynamic> orderDetails = {
      'id': orderId,
      'order_number': orderNumber,
      'delivery_id': orderId,
      'transaction_id': orderId,
      'total_amount': notification['total_amount'],
      'order_items': mappedItems,
      'status': notification['status'] ?? 'pending',
      'created_at': notification['timestamp'],
      'delivery_address': notification['delivery_address'] ??
          notification['shipping_address'] ??
          notification['address'],
      'contact_number': notification['contact_number'] ??
          notification['phone'] ??
          notification['user_phone'],
      'delivery_option': notification['delivery_option'] ??
          notification['shipping_method'] ??
          notification['delivery_method'],
    };

    // Fetch latest order from API to get actual status before navigating (critical for notification page)
    try {
      final result = await AuthService.getOrders();
      if (result['status'] == 'success' && result['data'] is List) {
        final rawOrders = result['data'] as List;
        Map<String, dynamic>? matchedOrder;
        String? bestDeliveryId;

        for (final o in rawOrders) {
          final ord = Map<String, dynamic>.from(o);
          final dId = ord['delivery_id']?.toString();
          final tId = ord['transaction_id']?.toString();
          final oId = ord['id']?.toString();
          final ordNum = ord['order_number']?.toString();

          final matches = (dId != null &&
                  (dId == orderId || dId == orderNumber)) ||
              (tId != null && (tId == orderId || tId == orderNumber)) ||
              (oId != null && (oId == orderId || oId == orderNumber)) ||
              (ordNum != null && (ordNum == orderId || ordNum == orderNumber));

          if (matches) {
            matchedOrder = ord;
            bestDeliveryId = dId ?? tId ?? oId ?? orderId;
            break;
          }
        }

        if (matchedOrder != null && bestDeliveryId != null) {
          String? apiStatus = matchedOrder['status']?.toString() ??
              matchedOrder['order_status']?.toString();
          if (apiStatus == null || apiStatus.isEmpty) {
            final dId = matchedOrder['delivery_id']?.toString();
            if (dId != null) {
              for (final o in rawOrders) {
                final ord = Map<String, dynamic>.from(o);
                if (ord['delivery_id']?.toString() == dId) {
                  final s = ord['status']?.toString() ??
                      ord['order_status']?.toString();
                  if (s != null && s.isNotEmpty) {
                    apiStatus = s;
                    break;
                  }
                }
              }
            }
          }
          if (apiStatus != null && apiStatus.isNotEmpty) {
            orderDetails['status'] = apiStatus;
            debugPrint(
                '📱 Got actual status from API for notification: $apiStatus');
          }
          orderDetails['delivery_id'] = bestDeliveryId;
          orderDetails['transaction_id'] = bestDeliveryId;
          orderDetails['id'] = bestDeliveryId;
        }
      }
    } catch (e) {
      debugPrint('📱 Could not fetch latest order status: $e');
    }

    debugPrint('📱 Navigating to OrderTrackingPage...');
    debugPrint('📱 Order details: $orderDetails');

    if (!mounted) return;

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            orderDetails: orderDetails,
          ),
          fullscreenDialog: false,
        ),
      );
      debugPrint('📱 OrderTrackingPage navigation successful!');
    } catch (e) {
      debugPrint('📱 Navigation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating to tracking page: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 100),
          ),
        );
      }
    }
  }

  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(url);
  }

  Future<void> _markNotificationAsRead(
      Map<String, dynamic> notification) async {
    final notificationId = notification['id'].toString();

    try {
      // use the right service method to mark as read
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
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);

    // Format timestamp
    String timeText = '';
    try {
      final timestamp = DateTime.parse(notification['timestamp']);
      timeText = DateFormat('MMM d, y • h:mm a').format(timestamp);
    } catch (e) {
      timeText = 'Just now';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              await _markNotificationAsRead(notification);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: Colors.grey.shade900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (notification['message']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true) ...[
                            Text(
                              notification['message'] ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (items.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: items
                                  .map<Widget>(
                                      (item) => _buildImageItemRow(item))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (orderNumber.isNotEmpty ||
                              totalAmount.isNotEmpty)
                            Row(
                              children: [
                                if (orderNumber.isNotEmpty) ...[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          orderNumber,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (totalAmount.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        totalAmount,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          if (orderNumber.isNotEmpty ||
                              totalAmount.isNotEmpty)
                            const SizedBox(height: 14),
                          if (status.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.green.shade100),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (notification['order_id'] != null ||
                              notification['order_number'] != null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _handleNotificationAction(
                                      notification);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Track order',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                height: 90,
                width: 90,
                memCacheWidth: 180,
                memCacheHeight: 180,
                placeholder: (context, url) => Container(
                  height: 90,
                  width: 90,
                  color: Colors.grey.shade100,
                  child: Icon(
                    Icons.image,
                    color: Colors.grey.shade400,
                    size: 28,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 90,
                  width: 90,
                  color: Colors.grey.shade100,
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey.shade400,
                    size: 28,
                  ),
                ),
              )
            : Container(
                height: 90,
                width: 90,
                color: Colors.grey.shade100,
                child: Icon(
                  Icons.inventory,
                  color: Colors.grey.shade400,
                  size: 28,
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
      case 'verified':
        return Icons.verified;
      case 'check_circle':
        return Icons.check_circle;
      case 'cancel':
        return Icons.cancel;
      case 'info':
        return Icons.info;
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
      case 'red':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
