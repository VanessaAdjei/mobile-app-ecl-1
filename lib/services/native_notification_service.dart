// services/native_notification_service.dart

//
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_handler_service.dart';
import '../pages/order_tracking_page.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('ecl_notifications');
  static final GlobalKey<NavigatorState> _globalNavigatorKey =
      GlobalKey<NavigatorState>();
  static String? _pendingNotificationPayload;
  static bool _nativeChannelAvailable = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    try {
      debugPrint('📱 Native: Initializing notification service...');

      // Test the method channel first
      debugPrint('📱 Native: Testing method channel...');
      try {
        final testResult = await _channel.invokeMethod('test');
        debugPrint('📱 Native: Test result: $testResult');
        _nativeChannelAvailable = true;
        debugPrint('📱 Native: Native channel is available');
      } catch (e) {
        debugPrint('📱 Native: Method channel test failed (expected): $e');
        _nativeChannelAvailable = false;
        debugPrint('📱 Native: Continuing with flutter_local_notifications...');
      }

      // Always init local plugin (permission requests + fallback when native fails).
      await _initializeLocalNotifications();

      // Check if notifications are enabled
      final isEnabled = await areNotificationsEnabled();
      debugPrint('📱 Native: Notifications enabled: $isEnabled');

      // Set up method call handler for immediate notification handling
      _channel.setMethodCallHandler((call) async {
        debugPrint('📱 Native: Received method call: ${call.method}');
        if (call.method == 'onNotificationOpened') {
          final data = call.arguments as Map<String, dynamic>?;
          if (data != null) {
            final payload = data['payload'] as String?;
            final action = data['action'] as String?;
            debugPrint(
                '📱 Native: Notification opened with payload: $payload, action: $action');

            // Store the payload for later handling
            if (payload != null && payload.isNotEmpty) {
              _pendingNotificationPayload = payload;
              debugPrint(
                  '📱 Native: Stored notification payload for later handling');
            }

            // Handle the notification immediately with action (non-blocking)
            if (payload != null && payload.isNotEmpty) {
              // Use microtask for faster execution
              Future.microtask(
                  () => _handleNotificationImmediately(payload, action));
            }
          }
        }
        return null;
      });

      debugPrint('📱 Native: Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing native notification service: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      // Don't throw the error, just log it and continue
      debugPrint('📱 Native: Continuing without native notifications...');
    }
  }

  /// Handle notification immediately when app is opened from notification
  static void _handleNotificationImmediately(String payload, String? action) {
    debugPrint(
        '📱 Native: Handling notification immediately: $payload, action: $action');

    // Use a global navigator key to handle navigation
    if (_globalNavigatorKey.currentState != null) {
      // Use immediate execution for faster response
      try {
        // Handle based on action for faster routing
        if (action == 'OPEN_ORDER_TRACKING') {
          _handleOrderTrackingNavigation(payload);
        } else {
          NotificationHandlerService.handleNotificationPayload(
            _globalNavigatorKey.currentContext!,
            payload,
          );
        }
        debugPrint('📱 Native: Notification handled successfully');
      } catch (e) {
        debugPrint('📱 Native: Error handling notification: $e');
      }
    } else {
      debugPrint('📱 Native: Navigator not ready yet, storing payload');
      _pendingNotificationPayload = payload;
    }
  }

  /// Handle order tracking navigation directly for faster response
  static void _handleOrderTrackingNavigation(String payload) {
    try {
      final Map<String, dynamic> data = json.decode(payload);
      final String orderId = data['order_id']?.toString() ?? '';
      final String orderNumber = data['order_number']?.toString() ?? '';

      if (orderId.isNotEmpty && orderNumber.isNotEmpty) {
        // Create order details map for OrderTrackingPage
        final Map<String, dynamic> orderDetails = {
          'id': orderId,
          'order_number': orderNumber,
          'status': data['status'] ?? 'Order Placed',
          'total_amount': data['total_amount'] ?? '0.00',
          'payment_method': data['payment_method'] ?? 'Unknown',
          'items': data['items'] ?? [],
          'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
        };

        // Navigate directly to order tracking page
        _globalNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => OrderTrackingPage(
              orderDetails: orderDetails,
            ),
          ),
        );
        debugPrint('📱 Native: Direct navigation to order tracking');
      }
    } catch (e) {
      debugPrint('📱 Native: Error in direct order tracking navigation: $e');
      // Fallback to general handler
      NotificationHandlerService.handleNotificationPayload(
        _globalNavigatorKey.currentContext!,
        payload,
      );
    }
  }

  static IOSFlutterLocalNotificationsPlugin? get _iosPlugin =>
      _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _pendingNotificationPayload = response.payload;
            Future.microtask(
                () => _handleNotificationImmediately(response.payload!, null));
          }
        },
      );
      // Do not request OS permission here — avoids a duplicate prompt before the user opts in.
      _localNotificationsInitialized = true;
      debugPrint('📱 Native: flutter_local_notifications initialized');
    } catch (e) {
      debugPrint('📱 Native: Failed to init flutter_local_notifications: $e');
    }
  }

  static Future<void> _showViaLocalNotifications(
    int id,
    String title,
    String body,
    String? payload,
  ) async {
    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        // Bump channel id so existing installs pick up sound/vibration settings.
        // Android notification channels are not fully editable after creation.
        'ecl_order_channel_v3',
        'Order Updates',
        channelDescription: 'Notifications for order status and updates',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification.wav',
        interruptionLevel: InterruptionLevel.active,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _localNotifications.show(id, title, body, details,
          payload: payload);
      debugPrint(
          '📱 Native: Notification shown via flutter_local_notifications');
    } catch (e) {
      debugPrint('📱 Native: flutter_local_notifications show failed: $e');
    }
  }

  /// True when the OS allows posting notifications (permission + system toggle).
  static Future<bool> canPostSystemNotifications() async {
    try {
      if (Platform.isIOS) {
        final ios = _iosPlugin;
        if (ios != null) {
          final settings = await ios.checkPermissions();
          final allowed = settings?.isEnabled ?? false;
          debugPrint(
            '📱 Native: iOS notification permission — '
            'enabled=$allowed alert=${settings?.isAlertEnabled} '
            'badge=${settings?.isBadgeEnabled} sound=${settings?.isSoundEnabled}',
          );
          return allowed;
        }
        debugPrint('📱 Native: iOS notification plugin unavailable');
        return false;
      }

      if (Platform.isAndroid && _nativeChannelAvailable) {
        final enabled =
            await _channel.invokeMethod<bool>('areNotificationsEnabled');
        if (enabled == false) {
          debugPrint('📱 Native: Android notifications disabled in system settings');
          return false;
        }
      }

      final status = await Permission.notification.status;
      if (!status.isGranted) {
        debugPrint('📱 Native: Notification permission not granted: $status');
        return false;
      }

      if (Platform.isAndroid && _nativeChannelAvailable) {
        final enabled =
            await _channel.invokeMethod<bool>('areNotificationsEnabled');
        return enabled ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('📱 Native: canPostSystemNotifications error: $e');
      return false;
    }
  }

  /// Requests OS permission when needed so system notifications can be shown.
  static Future<bool> ensureSystemNotificationsEnabled({
    BuildContext? context,
    bool requestIfNeeded = true,
  }) async {
    if (await canPostSystemNotifications()) return true;
    if (!requestIfNeeded) {
      debugPrint(
        '📱 Native: Notifications off — enable in Settings → Ernest Chemist → Notifications',
      );
      return false;
    }
    debugPrint('📱 Native: Requesting notification permission…');
    return requestNotificationPermissionDirect(context: context);
  }

  /// Show a system notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    bool checkPermission = true,
  }) async {
    try {
      debugPrint('📱 Native: Attempting to show notification: $title');
      debugPrint('📱 Native: Notification body: $body');

      if (!_localNotificationsInitialized) {
        await _initializeLocalNotifications();
      }

      if (checkPermission) {
        final allowed = await ensureSystemNotificationsEnabled(
          requestIfNeeded: true,
        );
        if (!allowed) {
          debugPrint(
            '📱 Native: Cannot show "$title" — notifications are off. '
            'Open Settings → Ernest Chemist → Notifications.',
          );
          return;
        }
      }

      final notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch % 2147483647;
      debugPrint('📱 Native: Using notification ID: $notificationId');

      // iOS uses flutter_local_notifications only (no Android-style method channel).
      if (Platform.isIOS) {
        await _showViaLocalNotifications(
          notificationId,
          title,
          body,
          payload,
        );
        return;
      }

      var shown = false;
      if (_nativeChannelAvailable) {
        try {
          await _channel.invokeMethod('showNotification', {
            'id': notificationId,
            'title': title,
            'body': body,
            'payload': payload,
          });
          shown = true;
          debugPrint(
              '📱 Native: Notification sent successfully via native channel!');
        } catch (e) {
          debugPrint(
              '📱 Native: Native notification failed, trying flutter_local_notifications: $e');
        }
      }
      if (!shown) {
        await _showViaLocalNotifications(
          notificationId,
          title,
          body,
          payload,
        );
      }
    } catch (e) {
      debugPrint('Error showing native notification: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      debugPrint('📱 Native: Would show notification: $title - $body');
    }
  }

  /// Test notification
  static Future<void> testNotification() async {
    await showNotification(
      title: 'Test Notification 📱',
      body: 'This is a test notification from Ernest Chemist!',
      payload: json.encode({
        'type': 'test',
        'message': 'Test notification',
      }),
    );
  }

  /// Get notification payload when app is opened from notification
  static Future<String?> getNotificationPayload() async {
    try {
      debugPrint('📱 Native: Getting notification payload...');
      // For now, return the stored pending payload since native implementation is not available
      // TODO: Implement native payload retrieval when platform channels are set up
      final payload = _pendingNotificationPayload;
      debugPrint('📱 Native: Returning stored payload: $payload');
      return payload;
    } catch (e) {
      debugPrint('Error getting notification payload: $e');
      return null;
    }
  }

  /// Get the global navigator key for notification handling
  static GlobalKey<NavigatorState> get globalNavigatorKey =>
      _globalNavigatorKey;

  /// Check if native channel is available
  static bool get isNativeChannelAvailable => _nativeChannelAvailable;

  /// Check if there's a pending notification payload
  static String? get pendingNotificationPayload => _pendingNotificationPayload;

  /// Clear pending notification payload
  static void clearPendingNotificationPayload() {
    debugPrint('📱 Native: Clearing pending notification payload');
    _pendingNotificationPayload = null;
  }

  /// Show order placed notification
  static Future<void> showOrderPlacedNotification({
    required String orderId,
    required String orderNumber,
    required String totalAmount,
  }) async {
    await showNotification(
      title: 'Order Placed Successfully! 🎉',
      body:
          'Order #$orderNumber has been placed successfully for $totalAmount.',
      payload: json.encode({
        'type': 'order_placed',
        'order_id': orderId,
        'order_number': orderNumber,
        'total_amount': totalAmount,
      }),
    );
  }

  /// Show order status notification
  static Future<void> showOrderStatusNotification({
    required String orderId,
    required String orderNumber,
    required String status,
    required String message,
  }) async {
    await showNotification(
      title: 'Order Status Update 📦',
      body: 'Order #$orderNumber: $message',
      payload: json.encode({
        'type': 'order_status',
        'order_id': orderId,
        'order_number': orderNumber,
        'status': status,
        'message': message,
      }),
    );
  }

  /// Show delivery notification
  static Future<void> showDeliveryNotification({
    required String orderId,
    required String orderNumber,
    required String message,
  }) async {
    await showNotification(
      title: 'Delivery Update 🚚',
      body: 'Order #$orderNumber: $message',
      payload: json.encode({
        'type': 'delivery_update',
        'order_id': orderId,
        'order_number': orderNumber,
        'message': message,
      }),
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      if (_nativeChannelAvailable) {
        await _channel.invokeMethod('cancelAllNotifications');
      }
      if (_localNotificationsInitialized) {
        await _localNotifications.cancelAll();
      }
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    return canPostSystemNotifications();
  }

  static Future<bool> isLocationWhenInUseGranted() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  /// True when at least one onboarding permission is still missing.
  static Future<bool> needsPermissionsPrompt() async {
    final notifications = await areNotificationsEnabled();
    final location = await isLocationWhenInUseGranted();
    return !notifications || !location;
  }

  /// Single OS location prompt (when-in-use) — no extra in-app dialog.
  static Future<bool> requestLocationWhenInUseDirect({BuildContext? context}) async {
    final dialogContext = context ?? globalNavigatorKey.currentContext;
    try {
      final perm = Permission.locationWhenInUse;
      var status = await perm.status;
      debugPrint('📱 Location when-in-use status: $status');

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (dialogContext != null && dialogContext.mounted) {
          await _showLocationSettingsDialog(dialogContext);
        }
        return false;
      }

      status = await perm.request();
      debugPrint('📱 Location request result: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  static Future<void> _showLocationSettingsDialog(BuildContext context) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location access'),
        content: const Text(
          'Location is off for this app. Enable it in Settings to see delivery options and distances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (open == true) await openAppSettings();
  }

  /// Notifications then location — used after onboarding / from settings.
  static Future<({bool notifications, bool location})>
      requestOnboardingPermissions({BuildContext? context}) async {
    final dialogContext = context ?? globalNavigatorKey.currentContext;
    final notifications = await requestNotificationPermissionDirect(
      context: dialogContext,
    );
    // Brief gap so the notification dialog can dismiss before location.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final location = await requestLocationWhenInUseDirect(
      context: dialogContext,
    );
    return (notifications: notifications, location: location);
  }

  static Future<bool> _requestAndroidNotificationPermissionNative() async {
    if (!_nativeChannelAvailable || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'requestPermissions',
      );
      final granted = result?['granted'] == true;
      debugPrint('📱 Android native notification permission: $granted');
      return granted;
    } catch (e) {
      debugPrint('📱 Android native permission request failed: $e');
      return false;
    }
  }

  /// Shows the OS notification prompt via flutter_local_notifications + permission_handler.
  static Future<bool> requestNotificationPermissionDirect({
    BuildContext? context,
  }) async {
    final dialogContext = context ?? globalNavigatorKey.currentContext;
    try {
      await _initializeLocalNotifications();

      if (await canPostSystemNotifications()) {
        return true;
      }

      if (Platform.isAndroid) {
        if (await _requestAndroidNotificationPermissionNative()) {
          return true;
        }
        final android = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        debugPrint('📱 Android notification plugin request: $granted');
        if (granted == true) return true;
      }

      if (Platform.isIOS) {
        final granted = await _iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
        debugPrint('📱 iOS notification plugin request: $granted');
        if (granted == true) return true;
      }

      final permission = Permission.notification;
      final status = await permission.status;
      debugPrint('📱 Notification permission status: $status');

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (dialogContext != null && dialogContext.mounted) {
          await _showPermissionSettingsDialog(dialogContext);
        }
        return false;
      }

      final result = await permission.request();
      debugPrint('📱 Notification permission request result: $result');
      return result.isGranted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> requestNotificationPermission(
    BuildContext context, {
    bool skipPreDialog = false,
  }) async {
    try {
      debugPrint('📱 Native: Requesting notification permission...');

      final permission = Permission.notification;
      final status = await permission.status;

      debugPrint('📱 Native: Current permission status: $status');

      if (status.isGranted) {
        return {
          'granted': true,
          'message': 'Notification permission already granted'
        };
      }

      if (status.isPermanentlyDenied) {
        if (!context.mounted) {
          return {
            'granted': false,
            'message': 'Context not mounted during permission check'
          };
        }
        return await _showPermissionSettingsDialog(context);
      }

      if (!skipPreDialog) {
        if (!context.mounted) {
          return {
            'granted': false,
            'message': 'Context not mounted during permission check'
          };
        }
        final userWantsPermission = await _showPermissionDialog(context);
        if (!userWantsPermission) {
          return {
            'granted': false,
            'message': 'User declined notification permission'
          };
        }
      }

      final permissionResult = await permission.request();
      final granted = permissionResult.isGranted;
      debugPrint('📱 Native: Permission request result: $granted');

      return {
        'granted': granted,
        'message': granted
            ? 'Notification permission granted'
            : 'Notification permission denied'
      };
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return {'granted': false, 'message': 'Error requesting permission: $e'};
    }
  }

  /// Show user-friendly permission request dialog
  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.blue[600],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enable Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay updated with your orders and important updates!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'We\'ll notify you about:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  _PermissionBenefit(
                    icon: Icons.shopping_bag_outlined,
                    text: 'Order confirmations and updates',
                  ),
                  _PermissionBenefit(
                    icon: Icons.local_shipping_outlined,
                    text: 'Delivery status and tracking',
                  ),
                  _PermissionBenefit(
                    icon: Icons.inventory_2_outlined,
                    text: 'Product availability alerts',
                  ),
                  _PermissionBenefit(
                    icon: Icons.local_offer_outlined,
                    text: 'Special offers and promotions',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Enable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Show dialog to go to settings when permission is permanently denied
  static Future<Map<String, dynamic>> _showPermissionSettingsDialog(
      BuildContext context) async {
    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: Colors.orange[600],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Permission Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Notifications are currently disabled. To enable notifications, please go to your device settings and allow notifications for this app.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldOpenSettings) {
      await openAppSettings();
      // Check permission status after returning from settings
      final permission = Permission.notification;
      final status = await permission.status;
      return {
        'granted': status.isGranted,
        'message': status.isGranted
            ? 'Permission granted'
            : 'Please enable notifications in settings'
      };
    }

    return {'granted': false, 'message': 'User cancelled settings access'};
  }
}

/// Widget for displaying permission benefits
class _PermissionBenefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionBenefit({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.green[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
