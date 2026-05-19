// pages/notifications.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/product_image_url.dart';
import '../services/auth_service.dart';
import '../services/order_history_transformer.dart';
import '../providers/notification_provider.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import 'order_tracking_page.dart';
import '../services/order_notification_service.dart';
import '../services/performance_service.dart';

const Color _kNotifPageBg = Color(0xFFF6F8FA);
const Color _kNotifPageBgMint = Color(0xFFEFFCF4);
const Color _kNotifAccent = Color(0xFF0D7A4C);

Widget _notifPageBackdrop({required Widget child}) {
  return DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _kNotifPageBgMint,
          _kNotifPageBg,
          _kNotifPageBg,
        ],
        stops: [0.0, 0.28, 1.0],
      ),
    ),
    child: child,
  );
}

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

  Widget _notificationsHeaderSliver() {
    return EclExpandableSliverAppBar(
      toolbarTitle: 'Notifications',
      heroTitle: 'Notifications',
      heroSubtitle: 'Orders & updates',
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, np, _) {
            if (np.unreadCount <= 0) {
              return const SizedBox.shrink();
            }
            return TextButton(
              onPressed: () async {
                await np.markAllAsRead();
                if (mounted) {
                  await _loadNotifications(forceRefresh: true);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                'Read all',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    );

    return Scaffold(
      backgroundColor: _kNotifPageBg,
      body: _notifPageBackdrop(
        child: isLoading
            ? CustomScrollView(
                controller: _scrollController,
                physics: scrollPhysics,
                slivers: [
                  _notificationsHeaderSliver(),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kNotifAccent.withValues(alpha: 0.08),
                                ),
                              ),
                              SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Loading notifications…',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : groupedNotifications.isEmpty
                ? CustomScrollView(
                    controller: _scrollController,
                    physics: scrollPhysics,
                    slivers: [
                      _notificationsHeaderSliver(),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadNotifications(forceRefresh: true),
                    color: _kNotifAccent,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: scrollPhysics,
                      slivers: [
                        _notificationsHeaderSliver(),
                        ..._buildNotificationListSlivers(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFECFDF5),
                    const Color(0xFFD1FAE5).withValues(alpha: 0.55),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFBBF7D0).withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kNotifAccent.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.mark_chat_unread_rounded,
                size: 34,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You\'re all caught up',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order confirmations, shipping updates, and alerts will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNotificationListSlivers() {
    final sortedDates = groupedNotifications.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final dateKey = sortedDates[index];
              final notifications = groupedNotifications[dateKey] ?? [];
              return _buildNotificationGroup(dateKey, notifications, index);
            },
            childCount: sortedDates.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildNotificationGroup(String dateKey,
      List<Map<String, dynamic>> notifications, int groupIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: groupIndex == 0 ? 4 : 14, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(dateKey),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(_getDateKey(notification), index);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showNotificationDetails(notification),
            splashColor: _kNotifAccent.withValues(alpha: 0.08),
            highlightColor: _kNotifAccent.withValues(alpha: 0.04),
            child: Ink(
              decoration: BoxDecoration(
                color: isRead ? Colors.white : const Color(0xFFF8FDFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRead
                      ? const Color(0xFFE8EEF2)
                      : const Color(0xFFBBF7D0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isRead)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.green.shade400,
                              _kNotifAccent,
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNotificationLeading(
                              notification: notification,
                              iconData: iconData,
                              iconColor: iconColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification['title'] ??
                                              'Notification',
                                          style: GoogleFonts.poppins(
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w600,
                                            fontSize: 14,
                                            color: const Color(0xFF0F172A),
                                            height: 1.25,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        timeText,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((notification['message'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      notification['message'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _kNotifAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 18),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFFCBD5E1),
                        size: 22,
                      ),
                    ),
                  ],
                ),
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
        content: Text(
          'Notification removed',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        showCloseIcon: true,
        backgroundColor: const Color(0xFF334155),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(12),
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
            content: Text(
              'No order information in this notification',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            backgroundColor: const Color(0xFFEA580C),
            dismissDirection: DismissDirection.down,
            showCloseIcon: true,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
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
      final apiItems = await _fetchMergedOrderItemsFromApi(
        orderId: orderId,
        orderNumber: orderNumber,
      );
      if (apiItems.length > mappedItems.length) {
        orderDetails['order_items'] = apiItems;
        orderDetails['is_multi_item'] = apiItems.length > 1;
        orderDetails['item_count'] = apiItems.length;
      }

      final result = await AuthService.getOrders();
      if (result['status'] == 'success' && result['data'] is List) {
        final rawOrders = result['data'] as List;
        final requestedIds = <String>{orderId, orderNumber}
          ..removeWhere((v) => v.isEmpty);
        final matchedRows = <dynamic>[];

        for (final o in rawOrders) {
          if (o is! Map) continue;
          final ord = Map<String, dynamic>.from(o);
          final candidateIds = <String>{
            ord['delivery_id']?.toString() ?? '',
            ord['transaction_id']?.toString() ?? '',
            ord['id']?.toString() ?? '',
            ord['order_number']?.toString() ?? '',
          }..removeWhere((v) => v.isEmpty);

          if (candidateIds.intersection(requestedIds).isNotEmpty) {
            matchedRows.add(ord);
          }
        }

        if (matchedRows.isNotEmpty) {
          final matchedOrder =
              Map<String, dynamic>.from(matchedRows.first as Map);
          final bestDeliveryId = matchedOrder['delivery_id']?.toString() ??
              matchedOrder['transaction_id']?.toString() ??
              matchedOrder['id']?.toString() ??
              orderId;

          String? apiStatus = matchedOrder['status']?.toString() ??
              matchedOrder['order_status']?.toString();
          if (apiStatus == null || apiStatus.isEmpty) {
            final dId = matchedOrder['delivery_id']?.toString();
            if (dId != null) {
              for (final o in rawOrders) {
                if (o is! Map) continue;
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

          void mergeIfMissing(String key) {
            final v = matchedOrder[key];
            if (v == null) return;
            final s = v.toString().trim();
            if (s.isEmpty) return;
            final existing = orderDetails[key]?.toString().trim() ?? '';
            if (existing.isEmpty) orderDetails[key] = v;
          }

          for (final key in [
            'delivery_option',
            'shipping_type',
            'shipping_method',
            'delivery_method',
            'pickup_site',
            'pickup_location',
            'pickup_city',
            'pickup_region',
            'addr_1',
          ]) {
            mergeIfMissing(key);
          }
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
            content: Text(
                'Error navigating to tracking page: $e • Swipe down to dismiss'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.down,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _extractNotificationItems(
    Map<String, dynamic> notification,
  ) {
    for (final key in ['items', 'order_items']) {
      final raw = notification[key];
      if (raw is List && raw.isNotEmpty) {
        return OrderNotificationService.normalizeNotificationItems(raw);
      }
    }
    return [];
  }

  String _resolveItemImageUrl(Map<String, dynamic> item) {
    final raw = coerceProductImageSource(
      item['product_img'] ??
          item['imageUrl'] ??
          item['image'] ??
          item['image_url'] ??
          item['product_image'] ??
          item['product_image_url'],
    );
    return _getImageUrl(raw);
  }

  Future<List<Map<String, dynamic>>> _fetchMergedOrderItemsFromApi({
    required String orderId,
    required String orderNumber,
  }) async {
    try {
      final result = await AuthService.getOrders();
      if (result['status'] != 'success' || result['data'] is! List) {
        return [];
      }

      final rawOrders = result['data'] as List;
      final requestedIds = <String>{orderId, orderNumber}
        ..removeWhere((v) => v.isEmpty);
      if (requestedIds.isEmpty) return [];

      final matchedRows = <dynamic>[];
      for (final o in rawOrders) {
        if (o is! Map) continue;
        final ord = Map<String, dynamic>.from(o);
        final candidateIds = <String>{
          ord['delivery_id']?.toString() ?? '',
          ord['transaction_id']?.toString() ?? '',
          ord['id']?.toString() ?? '',
          ord['order_number']?.toString() ?? '',
        }..removeWhere((v) => v.isEmpty);

        if (candidateIds.intersection(requestedIds).isNotEmpty) {
          matchedRows.add(ord);
        }
      }

      if (matchedRows.isEmpty) return [];

      final mergeKey =
          OrderHistoryTransformer.getTransactionId(matchedRows.first);
      final merged = matchedRows.length == 1
          ? OrderHistoryTransformer.processSingleOrder(
              matchedRows.first,
              mergeKey,
            )
          : OrderHistoryTransformer.processMultiOrder(
              matchedRows,
              mergeKey,
            );

      for (final key in ['order_items', 'items']) {
        final raw = merged[key];
        if (raw is List && raw.isNotEmpty) {
          return OrderNotificationService.normalizeNotificationItems(raw);
        }
      }
    } catch (e) {
      debugPrint('📱 Error fetching merged order items: $e');
    }
    return [];
  }

  Widget _buildNotificationLeading({
    required Map<String, dynamic> notification,
    required IconData iconData,
    required Color iconColor,
  }) {
    final items = _extractNotificationItems(notification);
    if (items.isEmpty) {
      return _buildNotificationIconAvatar(iconData, iconColor);
    }

    if (items.length == 1) {
      final imageUrl = _resolveItemImageUrl(items.first);
      if (imageUrl.isEmpty) {
        return _buildNotificationIconAvatar(iconData, iconColor);
      }
      return _buildNotificationImageTile(imageUrl, size: 44, radius: 12);
    }

    final visible = items.take(3).toList();
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 11.0,
              top: 4,
              child: _buildNotificationImageTile(
                _resolveItemImageUrl(visible[i]),
                size: 30,
                radius: 8,
                borderWidth: 1.5,
              ),
            ),
          if (items.length > 3)
            Positioned(
              right: -2,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _kNotifAccent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '+${items.length - 3}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationIconAvatar(IconData iconData, Color iconColor) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.15),
        ),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 22,
      ),
    );
  }

  Widget _buildNotificationImageTile(
    String imageUrl, {
    required double size,
    required double radius,
    double borderWidth = 1,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - borderWidth),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                memCacheWidth: (size * 2).round(),
                memCacheHeight: (size * 2).round(),
                placeholder: (context, url) => ColoredBox(
                  color: const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey.shade400,
                    size: size * 0.45,
                  ),
                ),
                errorWidget: (context, url, error) => ColoredBox(
                  color: const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey.shade400,
                    size: size * 0.45,
                  ),
                ),
              )
            : ColoredBox(
                color: const Color(0xFFF1F5F9),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.grey.shade400,
                  size: size * 0.45,
                ),
              ),
      ),
    );
  }

  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(url);
  }

  Future<void> _markNotificationAsRead(
      Map<String, dynamic> notification) async {
    final notificationId = notification['id'].toString();
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

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
      await notificationProvider.refreshUnreadCount();
    } catch (e) {
      debugPrint('📱 Error marking notification as read: $e');
    }
  }

  Future<void> _showNotificationDetails(
    Map<String, dynamic> notification,
  ) async {
    var items = _extractNotificationItems(notification);
    final orderId = notification['order_id']?.toString() ?? '';
    final orderNumber = notification['order_number']?.toString() ?? '';

    if (orderId.isNotEmpty || orderNumber.isNotEmpty) {
      try {
        final apiItems = await _fetchMergedOrderItemsFromApi(
          orderId: orderId,
          orderNumber: orderNumber,
        );
        if (apiItems.length > items.length) {
          items = apiItems;
        }
      } catch (e) {
        debugPrint('📱 Could not enrich notification items: $e');
      }
    }

    if (!mounted) return;
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxH = MediaQuery.of(sheetContext).size.height * 0.72;
        return PopScope(
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              await _markNotificationAsRead(notification);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                constraints: BoxConstraints(maxHeight: maxH),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: _kNotifAccent.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade500,
                              Colors.green.shade700,
                              Colors.green.shade800,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Swipe down to dismiss',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: iconColor.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Icon(
                                iconData,
                                color: iconColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification['title'] ?? 'Notification',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            14,
                            16,
                            12 + MediaQuery.of(sheetContext).padding.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (notification['message']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true) ...[
                                Text(
                                  notification['message'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF334155),
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (items.isNotEmpty) ...[
                                Text(
                                  'Items',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: items
                                      .map<Widget>(
                                        (item) => _buildImageItemRow(
                                          Map<String, dynamic>.from(item),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (orderNumber.isNotEmpty ||
                                  totalAmount.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _kNotifPageBgMint,
                                        _kNotifPageBg,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (orderNumber.isNotEmpty) ...[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: const Color(
                                                    0xFF64748B,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                orderNumber,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (totalAmount.isNotEmpty) ...[
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Total',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: const Color(
                                                  0xFF64748B,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              totalAmount,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: _kNotifAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (orderNumber.isNotEmpty ||
                                  totalAmount.isNotEmpty)
                                const SizedBox(height: 12),
                              if (status.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFBBF7D0),
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _kNotifAccent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (notification['order_id'] != null ||
                                  notification['order_number'] != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () async {
                                      Navigator.pop(sheetContext);
                                      await _handleNotificationAction(
                                        notification,
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _kNotifAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Track order',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
            ),
          ),
        );
      },
    );
  }

  /// Build image item row - just images
  Widget _buildImageItemRow(Map<String, dynamic> item) {
    final imageUrl = _resolveItemImageUrl(item);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                height: 76,
                width: 76,
                memCacheWidth: 152,
                memCacheHeight: 152,
                placeholder: (context, url) => Container(
                  height: 76,
                  width: 76,
                  color: const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 76,
                  width: 76,
                  color: const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
              )
            : Container(
                height: 76,
                width: 76,
                color: const Color(0xFFF1F5F9),
                child: Icon(
                  Icons.inventory_2_outlined,
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
        return _kNotifAccent;
    }
  }
}
