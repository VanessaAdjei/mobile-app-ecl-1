// pages/notifications.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottomnav.dart';
import 'homepage.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_service.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, List<Map<String, dynamic>>> groupedNotifications = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
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

  Future<void> _loadNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();

      // Check if there are any notification keys
      List<String> notificationKeys =
          keys.where((key) => key.startsWith('notification_')).toList();

      if (notificationKeys.isNotEmpty) {
        for (var key in notificationKeys) {
          List<String>? notificationStrings = prefs.getStringList(key);
          if (notificationStrings != null && notificationStrings.isNotEmpty) {
            try {
              List<Map<String, dynamic>> notifications =
                  notificationStrings.map((item) {
                Map<String, dynamic> notification =
                    Map<String, dynamic>.from(jsonDecode(item));
                // Convert string 'true'/'false' to boolean if needed
                notification['expanded'] =
                    _convertToBoolean(notification['expanded']);
                notification['read'] = _convertToBoolean(notification['read']);
                return notification;
              }).toList();

              // Extract the actual date from the key (removing the 'notification_' prefix)
              String dateKey = key.replaceFirst('notification_', '');
              groupedNotifications[dateKey] = notifications;
            } catch (e) {
              // Silently handle decoding errors
            }
          }
        }
      } else {
        // Add sample notifications for multiple days
        _addDailyNotifications();
      }
    } catch (e) {
      // If there's an error loading, add sample notifications anyway
      _addDailyNotifications();
    } finally {
      // Update UI regardless of success or failure
      if (mounted) {
        setState(() {
          isLoading = false;
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

  void _addDailyNotifications() {
    // Clear existing notifications to prevent duplicates
    groupedNotifications.clear();

    // Generate notifications for the last 7 days
    DateTime now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      DateTime date = now.subtract(Duration(days: i));
      String formattedDate = DateFormat("EEEE, MMM d").format(date);

      // Initialize the list for this date if it doesn't exist
      groupedNotifications[formattedDate] = [];

      // Add different types of notifications for each day
      if (i == 0) {
        // Today
        groupedNotifications[formattedDate]!.add({
          'title': 'Order Confirmation',
          'message':
              'Your order for Pain Relief Tablets has been confirmed and is being processed. You will receive a tracking number soon.',
          'time': '2:15 PM',
          'expanded': false,
          'read': false,
          'icon': 'confirmation',
        });

        groupedNotifications[formattedDate]!.add({
          'title': 'Shipping Update',
          'message':
              'Your order has been shipped and is on its way! Track your package with the tracking number provided.',
          'time': '3:45 PM',
          'expanded': false,
          'read': false,
          'icon': 'shipping',
        });
      } else if (i == 1) {
        // Yesterday
        groupedNotifications[formattedDate]!.add({
          'title': 'Product Available',
          'message':
              'The Vitamin D3 Supplement you requested is now back in stock! Order now before it runs out again.',
          'time': '9:00 AM',
          'expanded': false,
          'read': false,
          'icon': 'product',
        });

        groupedNotifications[formattedDate]!.add({
          'title': 'Order Delivered',
          'message':
              'Your order has been delivered. Thank you for shopping with us! We hope you enjoy your purchase.',
          'time': '5:30 PM',
          'expanded': false,
          'read': false,
          'icon': 'delivered',
        });
      } else if (i == 2) {
        // 2 days ago
        groupedNotifications[formattedDate]!.add({
          'title': 'Restock Reminder',
          'message':
              'It\'s time to refill your prescription for Blood Pressure Medication. Order now to avoid running out.',
          'time': '8:00 AM',
          'expanded': false,
          'read': false,
          'icon': 'reminder',
        });

        groupedNotifications[formattedDate]!.add({
          'title': 'Payment Successful',
          'message':
              'Your payment for the order Pain Relief Bundle has been successfully processed. Thank you!',
          'time': '2:50 PM',
          'expanded': false,
          'read': false,
          'icon': 'payment',
        });
      } else if (i == 3) {
        // 3 days ago
        groupedNotifications[formattedDate]!.add({
          'title': 'Weekly Health Tip',
          'message':
              'Remember to stay hydrated! Drinking enough water helps maintain healthy blood pressure and supports overall health.',
          'time': '10:30 AM',
          'expanded': false,
          'read': false,
          'icon': 'reminder',
        });
      } else if (i == 4) {
        // 4 days ago
        groupedNotifications[formattedDate]!.add({
          'title': 'Order Status Update',
          'message':
              'Your order is currently being processed. We will notify you once it ships.',
          'time': '7:45 PM',
          'expanded': false,
          'read': false,
          'icon': 'status',
        });
      } else if (i == 5) {
        // 5 days ago
        groupedNotifications[formattedDate]!.add({
          'title': 'Special Offer',
          'message':
              'Get 20% off on all vitamins this week! Use code HEALTH20 at checkout.',
          'time': '11:20 AM',
          'expanded': false,
          'read': false,
          'icon': 'product',
        });
      } else if (i == 6) {
        // 6 days ago
        groupedNotifications[formattedDate]!.add({
          'title': 'Order Cancellation',
          'message':
              'Your order for Cough Syrup has been canceled due to an issue with payment. Please check your payment details.',
          'time': '6:30 PM',
          'expanded': false,
          'read': false,
          'icon': 'cancel',
        });

        groupedNotifications[formattedDate]!.add({
          'title': 'New Product Alert',
          'message':
              'Check out our new range of organic supplements now available in the store!',
          'time': '4:15 PM',
          'expanded': false,
          'read': false,
          'icon': 'product',
        });
      }

      // Add a generic notification to each day
      groupedNotifications[formattedDate]!.add({
        'title': 'Daily Health Reminder',
        'message':
            'Remember to take your medications as prescribed and maintain a healthy routine.',
        'time':
            i == 0 ? '8:00 AM' : '${8 + i % 4}:${i % 2 == 0 ? '00' : '30'} AM',
        'expanded': false,
        'read': false,
        'icon': 'reminder',
      });
    }

    // Save the notifications to SharedPreferences
    _saveNotifications();
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
          leading: BackButtonUtils.simple(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
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
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(color: theme.primaryColor))
            : groupedNotifications.isNotEmpty
                ? ListView(
                    padding: const EdgeInsets.all(12.0),
                    children: [
                      ...groupedNotifications.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entryWithIndex) {
                        int i = entryWithIndex.key;
                        var entry = entryWithIndex.value;
                        return Animate(
                          effects: [
                            FadeEffect(duration: 400.ms, delay: (i * 80).ms),
                            SlideEffect(
                                duration: 400.ms,
                                begin: Offset(0, 0.1),
                                end: Offset(0, 0),
                                delay: (i * 80).ms),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0, vertical: 8.0),
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
                                      entry.key,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme
                                                .textTheme.titleMedium?.color ??
                                            Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (entry.value.isNotEmpty)
                                ...entry.value
                                    .asMap()
                                    .entries
                                    .map((notification) {
                                  int index = notification.key;
                                  return Animate(
                                    effects: [
                                      FadeEffect(
                                          duration: 400.ms,
                                          delay: (index * 60).ms),
                                      SlideEffect(
                                          duration: 400.ms,
                                          begin: Offset(0, 0.1),
                                          end: Offset(0, 0),
                                          delay: (index * 60).ms),
                                    ],
                                    child: _buildNotificationTile(
                                        entry.key, index, notification.value),
                                  );
                                }),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      }),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "No notifications yet",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "When you receive notifications, they'll appear here",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                            });
                            _addDailyNotifications();
                            setState(() {
                              isLoading = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Generate Sample Notifications",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: const CustomBottomNav(),
      ),
    );
  }

  Widget _buildNotificationTile(
      String group, int index, Map<String, dynamic> notification) {
    bool isExpanded = _convertToBoolean(notification['expanded']);
    bool isRead = _convertToBoolean(notification['read']);
    IconData iconData = _getIconForNotification(notification['icon']);
    Color iconColor = _getColorForNotification(notification['icon']);

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(group, index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isRead
              ? null
              : Border.all(
                  color: Colors.green.withValues(alpha: 0.3), width: 1),
        ),
        child: InkWell(
          onTap: () {
            _toggleExpand(group, index);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification['message'] ?? '',
                            maxLines: isExpanded ? null : 2,
                            overflow: isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Handle action specific to this notification type
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: iconColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _getActionText(notification['icon']),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      notification['time'] ?? '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Divider(color: Colors.grey[300]),
                  ),
                if (isExpanded)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _deleteNotification(group, index);
                        },
                        icon: Icon(Icons.delete_outline,
                            size: 16, color: Colors.red[400]),
                        label: Text(
                          'Delete',
                          style:
                              TextStyle(color: Colors.red[400], fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(120, 36),
                        ),
                      ),
                    ],
                  ),
              ],
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
    switch (iconType) {
      case 'confirmation':
        return 'View Order';
      case 'shipping':
        return 'Track Package';
      case 'product':
        return 'Buy Now';
      case 'delivered':
        return 'Rate Product';
      case 'reminder':
        return 'Reorder';
      case 'payment':
        return 'View Receipt';
      case 'cancel':
        return 'Contact Support';
      case 'status':
        return 'Check Status';
      default:
        return '';
    }
  }
}
