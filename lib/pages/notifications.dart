// pages/notifications.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'bottomnav.dart';
import 'homepage.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_service.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/order_notification_service.dart';
import '../services/native_notification_service.dart';
import 'notification_provider.dart';
import 'order_tracking_page.dart';

// Test import
void _testImport() {
  // This is just to test if the import works
  debugPrint('📱 OrderTrackingPage import test');
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<String, List<Map<String, dynamic>>> groupedNotifications = {};
  bool isLoading = true;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, DateTime> _lastRefreshTimes = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });

    // Add scroll listener for infinite scroll optimization
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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

      // Get notifications from the new service
      final notifications = await OrderNotificationService.getNotifications();

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
      bool isCurrentlyExpanded =
          _convertToBoolean(groupedNotifications[group]?[index]['expanded']);
      groupedNotifications[group]?[index]['expanded'] = !isCurrentlyExpanded;
      groupedNotifications[group]?[index]['read'] = true;
    });

    _saveNotifications();
  }

  // Test notification method removed - system notifications are now working

  // Test system notification method removed - system notifications are now working

  // Test methods removed - system notifications are now working

  // Test options removed - system notifications are now working

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Notifications'),
          content:
              const Text('Are you sure you want to clear all notifications?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Clear All'),
              onPressed: () {
                setState(() {
                  groupedNotifications.clear();
                });
                _saveNotifications();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All notifications cleared'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getIconForNotification(String? iconType) {
    switch (iconType) {
      case 'confirmation':
        return Icons.check_circle_outline;
      case 'shipping':
        return Icons.local_shipping;
      case 'product':
        return Icons.inventory;
      case 'delivered':
        return Icons.inventory_2;
      case 'reminder':
        return Icons.notification_important;
      case 'payment':
        return Icons.payments;
      case 'cancel':
        return Icons.cancel_outlined;
      case 'status':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForNotification(String? iconType) {
    switch (iconType) {
      case 'confirmation':
        return Colors.green;
      case 'shipping':
        return Colors.blue;
      case 'product':
        return Colors.purple;
      case 'delivered':
        return Colors.teal;
      case 'reminder':
        return Colors.orange;
      case 'payment':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      case 'status':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
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
          title: Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                onPressed: _clearAllNotifications,
              ),
            ),
          ],
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(color: theme.primaryColor))
            : groupedNotifications.isNotEmpty
                ? RefreshIndicator(
                    onRefresh: () => _loadNotifications(forceRefresh: true),
                    color: theme.primaryColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12.0),
                      itemCount:
                          groupedNotifications.length + (_isRefreshing ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == groupedNotifications.length) {
                          // Show loading indicator at the bottom
                          return _isRefreshing
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }

                        final entry =
                            groupedNotifications.entries.elementAt(index);
                        return _buildNotificationGroup(
                            entry.key, entry.value, index);
                      },
                    ),
                  )
                : _buildEmptyState(theme),
        bottomNavigationBar: const CustomBottomNav(),
        // Test buttons removed - system notifications are now working
      ),
    );
  }

  Widget _buildNotificationTile(
      String group, int index, Map<String, dynamic> notification) {
    // Use cached values to avoid recalculating
    final bool isRead = notification['is_read'] == true;
    final IconData iconData = _getNotificationIcon(notification);
    final Color iconColor = _getNotificationColor(notification);

    // Format timestamp
    String timeText = '';
    try {
      final timestamp = DateTime.parse(notification['timestamp']);
      timeText = DateFormat('MMM dd, h:mm a').format(timestamp);
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
        _deleteNotification(group, index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isRead
                ? [Colors.white, Colors.grey.shade50]
                : [Colors.green.shade50, Colors.green.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
          border: isRead
              ? Border.all(color: Colors.grey.shade200, width: 1)
              : Border.all(
                  color: Colors.green.shade300,
                  width: 2,
                ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // Mark notification as read when tapped
              if (!isRead) {
                final notificationProvider =
                    Provider.of<NotificationProvider>(context, listen: false);
                await notificationProvider.markAsRead(notification['id']);
              }

              // Show notification details or perform action based on type
              _handleNotificationTap(notification);
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: iconColor.withValues(alpha: 0.1),
            highlightColor: iconColor.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animated icon container
                      Animate(
                        effects: [
                          ScaleEffect(
                            duration: 300.ms,
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.0, 1.0),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                iconColor.withValues(alpha: 0.1),
                                iconColor.withValues(alpha: 0.2),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _buildColorfulMainIcon(notification['icon']),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Content area
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and status badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification['title'] ?? '',
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.grey.shade800,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Animate(
                                    effects: [
                                      FadeEffect(duration: 400.ms),
                                      ScaleEffect(
                                        duration: 400.ms,
                                        begin: const Offset(0.5, 0.5),
                                      ),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade400,
                                            Colors.green.shade600,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'NEW',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Message
                            Text(
                              notification['message'] ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                height: 1.4,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Footer with action and time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Action button
                      Animate(
                        effects: [FadeEffect(duration: 500.ms, delay: 200.ms)],
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                iconColor.withValues(alpha: 0.1),
                                iconColor.withValues(alpha: 0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _handleNotificationAction(notification);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildColorfulActionIcon(
                                        notification['icon']),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getActionText(notification['icon']),
                                      style: TextStyle(
                                        color: iconColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Time
                      Animate(
                        effects: [FadeEffect(duration: 500.ms, delay: 300.ms)],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Delete button (only show on long press or in expanded view)
                  if (!isRead) ...[
                    const SizedBox(height: 12),
                    Animate(
                      effects: [FadeEffect(duration: 500.ms, delay: 400.ms)],
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _deleteNotification(group, index),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete Notification',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
    // All notifications now lead to order tracking
    return 'Track Order';
  }

  /// Handle notification action - navigate to order tracking
  void _handleNotificationAction(Map<String, dynamic> notification) {
    final orderId = notification['order_id']?.toString() ?? '';
    final orderNumber = notification['order_number']?.toString() ?? '';

    debugPrint('📱 Action button tapped - navigating to tracking');
    debugPrint('📱 Order ID: $orderId');
    debugPrint('📱 Order Number: $orderNumber');

    // Close the notification dialog first
    Navigator.pop(context);

    // Create order details map for tracking page
    final items = notification['items'] ?? [];
    final mappedItems = items
        .map((item) => {
              'product_name': item['name'] ?? 'Unknown Product',
              'product_img': item['imageUrl'] ?? '',
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
      // Fallback - show a message and try to navigate to a simpler page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navigating to tracking page: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin:
              EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 100),
        ),
      );

      // Try to navigate to purchases page as fallback
      try {
        Navigator.pushNamed(context, '/purchases');
      } catch (fallbackError) {
        debugPrint('📱 Fallback navigation also failed: $fallbackError');
      }
    }
  }

  /// Build colorful main notification icon widget
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
      case 'payment':
        return Icon(
          Icons.payment,
          color: Colors.teal.shade600,
          size: 24,
        );
      case 'reminder':
        return Icon(
          Icons.refresh,
          color: Colors.indigo.shade600,
          size: 24,
        );
      case 'cancel':
        return Icon(
          Icons.support_agent,
          color: Colors.red.shade600,
          size: 24,
        );
      case 'status':
        return Icon(
          Icons.info,
          color: Colors.amber.shade600,
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

  /// Build colorful action icon widget
  Widget _buildColorfulActionIcon(String? iconType) {
    switch (iconType) {
      case 'product':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade400,
                Colors.orange.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.shopping_cart,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'confirmation':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade400,
                Colors.green.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.receipt,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'shipping':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'delivered':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade400,
                Colors.purple.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.star,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'payment':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade400,
                Colors.teal.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.payment,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'reminder':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade400,
                Colors.indigo.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.refresh,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'cancel':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade400,
                Colors.red.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.support_agent,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'status':
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.shade400,
                Colors.amber.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.info,
            color: Colors.white,
            size: 12,
          ),
        );
      default:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade400,
                Colors.grey.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 12,
          ),
        );
    }
  }

  /// Get action icon for notification type
  IconData _getActionIcon(String? iconType) {
    switch (iconType) {
      case 'confirmation':
        return Icons.receipt;
      case 'shipping':
        return Icons.local_shipping;
      case 'product':
        return Icons.shopping_cart_outlined;
      case 'delivered':
        return Icons.star;
      case 'reminder':
        return Icons.refresh;
      case 'payment':
        return Icons.payment;
      case 'cancel':
        return Icons.support_agent;
      case 'status':
        return Icons.info;
      default:
        return Icons.arrow_forward;
    }
  }

  /// Get icon for notification based on type
  IconData _getNotificationIcon(Map<String, dynamic> notification) {
    final iconName = notification['icon']?.toString() ?? 'info';
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'hourglass_empty':
        return Icons.hourglass_empty;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'check_circle':
        return Icons.check_circle;
      case 'done_all':
        return Icons.done_all;
      case 'cancel':
        return Icons.cancel;
      case 'money_off':
        return Icons.money_off;
      case 'info':
      default:
        return Icons.info;
    }
  }

  void _debugNotificationCount() async {
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      final unreadCount = await OrderNotificationService.getUnreadCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Debug: Provider count: ${notificationProvider.unreadCount}, Service count: $unreadCount'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error debugging notification count: $e');
    }
  }

  void _refreshNotificationCount() async {
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.refreshUnreadCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Badge refreshed! Unread count: ${notificationProvider.unreadCount}'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Force a rebuild of the bottom navigation
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error refreshing notification count: $e');
    }
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
    try {
      final notificationType = notification['type']?.toString() ?? '';
      final orderId = notification['order_id']?.toString() ?? '';
      final orderNumber = notification['order_number']?.toString() ?? '';
      final items = notification['items'] as List<dynamic>? ?? [];
      final iconType = notification['icon']?.toString() ?? '';

      debugPrint('📱 Notification tapped: $notificationType');
      debugPrint('📱 Order ID: $orderId');
      debugPrint('📱 Order Number: $orderNumber');

      // Show minimal, clean notification dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simple header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification)
                        .withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getNotificationColor(notification),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getNotificationIcon(notification),
                          color: Colors.white,
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM dd, h:mm a').format(
                                  DateTime.parse(notification['timestamp'])),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
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
                            notification['total_amount']
                                    ?.toString()
                                    ?.isNotEmpty ==
                                true) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (orderNumber.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Order: ',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        orderNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (notification['total_amount']
                                      ?.toString()
                                      ?.isNotEmpty ==
                                  true) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Amount: ',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      notification['total_amount'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Simple action button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                _handleNotificationAction(notification),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _getNotificationColor(notification),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _getActionText(iconType),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      // Fallback: just show a simple message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification: ${notification['title']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'GH₵$price',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  /// Build detail row for order information
  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
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
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
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
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GH₵$price',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  /// Build optimized notification group widget
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
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateKey(dateKey),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        theme.textTheme.titleMedium?.color ?? Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Notifications in this group
          if (notifications.isNotEmpty)
            ...notifications.asMap().entries.map((notificationEntry) {
              final index = notificationEntry.key;
              final notification = notificationEntry.value;

              return Animate(
                effects: [
                  FadeEffect(duration: 400.ms, delay: (index * 60).ms),
                  SlideEffect(
                    duration: 400.ms,
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                    delay: (index * 60).ms,
                  ),
                ],
                child: _buildNotificationTile(dateKey, index, notification),
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Format date key for display
  String _formatDateKey(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateToCheck = DateTime(date.year, date.month, date.day);

      if (dateToCheck == today) {
        return 'Today';
      } else if (dateToCheck == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      return dateKey;
    }
  }

  /// Build optimized empty state widget
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Animate(
            effects: [
              FadeEffect(duration: 600.ms),
              ScaleEffect(duration: 600.ms, begin: const Offset(0.8, 0.8)),
            ],
            child: Icon(
              Icons.notifications_off,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Animate(
            effects: [FadeEffect(duration: 600.ms, delay: 200.ms)],
            child: Text(
              "No notifications yet",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Animate(
            effects: [FadeEffect(duration: 600.ms, delay: 400.ms)],
            child: Text(
              "When you receive notifications, they'll appear here",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Test buttons removed - system notifications are now working
        ],
      ),
    );
  }

  /// Get color for notification based on type
  Color _getNotificationColor(Map<String, dynamic> notification) {
    final colorName = notification['color']?.toString() ?? 'blue';
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
