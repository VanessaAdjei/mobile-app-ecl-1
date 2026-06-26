// pages/order_tracking_page.dart
import 'dart:async';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/utils/order_steps_api_logger.dart';
import 'package:eclapp/utils/order_tracking_timeline_helper.dart';
import 'package:eclapp/widgets/order_tracking/order_tracking_bill_card.dart';
import 'package:eclapp/widgets/order_tracking/order_tracking_delivery_card.dart';
import 'package:eclapp/widgets/order_tracking/order_tracking_status_card.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_items_card.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/order_tracking_provider.dart';
import '../services/order_tracking_service.dart';
import '../services/auth_service.dart';
import '../models/order_tracking_page_details.dart';
import '../utils/order_tracking_page_resolver.dart';
import '../utils/order_timestamp_parser.dart';
import '../config/api_config.dart';
import 'app_back_button.dart';

class OrderTrackingPage extends StatefulWidget {
  final Map<String, dynamic> orderDetails;

  const OrderTrackingPage({
    super.key,
    required this.orderDetails,
  });

  @override
  OrderTrackingPageState createState() => OrderTrackingPageState();
}

class OrderTrackingPageState extends State<OrderTrackingPage> {
  final OrderTrackingService _orderTrackingService = OrderTrackingService();
  static const Color _accent = PostCheckoutDesign.accent;

  String? _deliveryAddress;
  String? _contactNumber;
  String? _deliveryOption;
  bool _isLoading = true;
  double? _actualTotalAmount; // Store actual total fetched from API if needed
  double?
      _actualDeliveryFee; // Store actual delivery fee fetched from API if needed
  /// Current order status for timeline; updated from API so progression can move.
  String? _orderStatus;
  OrderTrackingStage? _timelineStage;
  Map<String, DateTime> _stageTimes = const {};
  DateTime? _placedAt;

  /// Full line-item list after merging API rows (multi-product orders).
  List<Map<String, dynamic>>? _resolvedOrderItems;

  /// Timer for periodic order status refresh while page is open
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 8);

  /// Shown in the track-order sliver header (toolbar + expanded): order id only.
  String _sliverHeaderOrderLabel() {
    final o = widget.orderDetails;
    final raw = o['order_number']?.toString() ??
        o['delivery_id']?.toString() ??
        o['transaction_id']?.toString() ??
        o['order_id']?.toString() ??
        o['id']?.toString() ??
        '';
    final t = raw.trim();
    if (t.isEmpty || t.toUpperCase() == 'N/A') return 'Order';
    return t.startsWith('#') ? t : '#$t';
  }

  bool _isPickupOrder() {
    bool mentionsPickup(String? v) {
      final n = (v ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      return n.contains('pickup') ||
          n.contains('instore') ||
          n.contains('instorepickup') ||
          n == 'collect';
    }

    final o = widget.orderDetails;
    final candidates = <String?>[
      _deliveryOption,
      o['delivery_option']?.toString(),
      o['shipping_type']?.toString(),
      o['shipping_method']?.toString(),
      o['delivery_method']?.toString(),
      o['shipping']?.toString(),
      o['fulfillment_type']?.toString(),
      o['order_type']?.toString(),
    ];
    if (candidates.any(mentionsPickup)) return true;

    for (final k in [
      'pickup_site',
      'pickup_location',
      'pickup_city',
      'pickup_region',
    ]) {
      if ((o[k]?.toString().trim().isNotEmpty ?? false)) return true;
    }

    final addr1 = o['addr_1']?.toString().toLowerCase().trim() ?? '';
    if (addr1 == 'pickup order' || addr1.contains('pickup')) return true;

    final addr =
        (o['delivery_address'] ?? o['shipping_address'] ?? o['address'] ?? '')
            .toString()
            .toLowerCase();
    if (addr.contains('pickup at') ||
        addr.startsWith('pickup ') ||
        addr.contains(' collect at')) {
      return true;
    }

    return false;
  }

  String _pickupLocationSummary() {
    final o = widget.orderDetails;
    final parts = <String>[];
    void add(dynamic raw) {
      if (raw == null) return;
      final s = raw.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'pickup order') return;
      if (!parts.contains(s)) parts.add(s);
    }

    add(o['pickup_site']);
    add(o['pickup_location']);
    add(o['pickup_city']);
    add(o['pickup_region']);
    if (parts.isNotEmpty) return parts.join(' · ');
    final addr = _deliveryAddress?.trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return 'Not available';
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 OrderTrackingPage initState called');
    debugPrint('🔍 Order details in initState: ${widget.orderDetails}');
    debugPrint(
        '🔍 All order details keys: ${widget.orderDetails.keys.toList()}');
    // Log delivery fee related fields
    debugPrint('🔍 Delivery fee fields check:');
    debugPrint('🔍   delivery_fee: ${widget.orderDetails['delivery_fee']}');
    debugPrint('🔍   deliveryFee: ${widget.orderDetails['deliveryFee']}');
    debugPrint('🔍   total_price: ${widget.orderDetails['total_price']}');
    debugPrint('🔍   amount: ${widget.orderDetails['amount']}');
    debugPrint(
        'Current navigation stack depth: ${Navigator.of(context).widget.observers.length}');
    debugPrint('Can pop current context: ${Navigator.canPop(context)}');
    final initialItems = _extractItemsList(widget.orderDetails);
    if (initialItems.isNotEmpty) {
      _resolvedOrderItems = initialItems;
    }
    unawaited(
      _orderTrackingService.primeMonotonicCache(_orderStorageKey()),
    );
    _loadDeliveryInfo();
    OrderTrackingProvider.registerPushRefresh(_onPushStatusRefresh);

    // If delivery fee is missing, try to retrieve it from stored preferences
    final hasDeliveryFee = widget.orderDetails['delivery_fee'] != null ||
        widget.orderDetails['deliveryFee'] != null;
    if (!hasDeliveryFee) {
      debugPrint(
          '🔍 Delivery fee missing - trying to retrieve from stored data...');
      _loadStoredDeliveryFee();
    }

    // Start periodic refresh so order status updates automatically while page is open
    unawaited(_fetchOrderDetailsFromAPI());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) unawaited(_fetchOrderDetailsFromAPI());
    });
  }

  @override
  void dispose() {
    OrderTrackingProvider.unregisterPushRefresh(_onPushStatusRefresh);
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  void _onPushStatusRefresh({String? status, String? orderId}) {
    if (!mounted) return;
    unawaited(_fetchOrderDetailsFromAPI());
  }

  String _orderStorageKey() {
    final o = widget.orderDetails;
    return o['transaction_id']?.toString() ??
        o['delivery_id']?.toString() ??
        o['order_number']?.toString() ??
        o['id']?.toString() ??
        '';
  }

  Future<void> _loadDeliveryInfo() async {
    try {
      debugPrint('🔍 Loading delivery info for order tracking...');
      debugPrint('🔍 Order details available: ${widget.orderDetails}');
      final isLoggedIn = await AuthService.isLoggedIn();
      debugPrint('🔍 User logged in: $isLoggedIn');

      final orderDetails = widget.orderDetails;

      String? notificationAddress =
          orderDetails['delivery_address']?.toString() ??
              orderDetails['shipping_address']?.toString() ??
              orderDetails['address']?.toString() ??
              orderDetails['addr_1']?.toString() ??
              orderDetails['region']?.toString() ??
              orderDetails['city']?.toString();

      String? notificationContact =
          orderDetails['contact_number']?.toString() ??
              orderDetails['phone']?.toString() ??
              orderDetails['user_phone']?.toString() ??
              orderDetails['user_phone_number']?.toString();

      String? notificationDeliveryOption =
          orderDetails['delivery_option']?.toString() ??
              orderDetails['shipping_method']?.toString() ??
              orderDetails['delivery_method']?.toString() ??
              orderDetails['shipping_type']?.toString();

      debugPrint('🔍 Delivery info from notification:');
      debugPrint('🔍 Address: $notificationAddress');
      debugPrint('🔍 Contact: $notificationContact');
      debugPrint('🔍 Option: $notificationDeliveryOption');

      debugPrint('🔍 All available fields in order details:');
      orderDetails.forEach((key, value) {
        if (key.toString().toLowerCase().contains('address') ||
            key.toString().toLowerCase().contains('phone') ||
            key.toString().toLowerCase().contains('delivery') ||
            key.toString().toLowerCase().contains('shipping')) {
          debugPrint('🔍 $key: $value');
        }
      });

      if (notificationAddress == null || notificationAddress.isEmpty) {
        final region = orderDetails['region']?.toString();
        final city = orderDetails['city']?.toString();
        final addr1 = orderDetails['addr_1']?.toString();

        if (region != null || city != null || addr1 != null) {
          final addressParts = <String>[];
          if (addr1 != null && addr1.isNotEmpty) addressParts.add(addr1);
          if (city != null && city.isNotEmpty) addressParts.add(city);
          if (region != null && region.isNotEmpty) addressParts.add(region);

          if (addressParts.isNotEmpty) {
            notificationAddress = addressParts.join(', ');
            debugPrint('🔍 Constructed delivery address: $notificationAddress');
          }
        }
      }

      // if we dont have delivery info from notification, try getting it from the api
      if (notificationAddress == null || notificationAddress.isEmpty) {
        if (isLoggedIn) {
          debugPrint(
              '🔍 No delivery address in notification, trying to fetch from API...');

          // check if we have a delivery_id we can use
          final deliveryId = orderDetails['delivery_id']?.toString();
          if (deliveryId != null && deliveryId.isNotEmpty) {
            debugPrint(
                '🔍 Found delivery_id: $deliveryId - this might contain delivery info');
          }

          // first try to get delivery info from their saved address
          debugPrint('🔍 Trying to fetch user\'s saved delivery info...');
          final deliveryData =
              await _orderTrackingService.fetchSavedDeliveryInfo();

          if (deliveryData != null) {
            debugPrint('🔍 Successfully fetched delivery info: $deliveryData');

            // get delivery info from the saved data
            final savedAddress = deliveryData['address']?.toString() ??
                deliveryData['addr_1']?.toString();
            final savedRegion = deliveryData['region']?.toString();
            final savedCity = deliveryData['city']?.toString();

            if (savedAddress != null && savedAddress.isNotEmpty) {
              notificationAddress = savedAddress;
              debugPrint(
                  '🔍 Found saved delivery address: $notificationAddress');
            } else if (savedRegion != null || savedCity != null) {
              final addressParts = <String>[];
              if (savedAddress != null && savedAddress.isNotEmpty) {
                addressParts.add(savedAddress);
              }
              if (savedCity != null && savedCity.isNotEmpty) {
                addressParts.add(savedCity);
              }
              if (savedRegion != null && savedRegion.isNotEmpty) {
                addressParts.add(savedRegion);
              }

              if (addressParts.isNotEmpty) {
                notificationAddress = addressParts.join(', ');
                debugPrint(
                    '🔍 Constructed address from saved delivery info: $notificationAddress');
              }
            }

            // get contact info
            final savedContact = deliveryData['phone']?.toString();
            if (savedContact != null && savedContact.isNotEmpty) {
              notificationContact = savedContact;
              debugPrint('🔍 Found saved contact number: $notificationContact');
            }

            // get delivery option
            final savedDeliveryOption =
                deliveryData['delivery_option']?.toString() ??
                    deliveryData['shipping_type']?.toString();
            if (savedDeliveryOption != null && savedDeliveryOption.isNotEmpty) {
              notificationDeliveryOption = savedDeliveryOption;
              debugPrint(
                  '🔍 Found saved delivery option: $notificationDeliveryOption');
            }
          } else {
            debugPrint('🔍 No saved delivery info found, trying orders API...');
            await _fetchOrderDetailsFromAPI();
          }
        } else {
          debugPrint(
              '🔍 User not logged in, cannot fetch delivery details from API');
          debugPrint('🔍 Delivery details will show default values');
        }
      }

      // if we still dont have delivery info, try shared preferences
      final prefs = await SharedPreferences.getInstance();

      final initialStatus =
          widget.orderDetails['status']?.toString() ?? 'Processing';
      final key = _orderStorageKey();
      final apiStage = _orderTrackingService.normalizeStage(initialStatus);
      final initialStage = key.isNotEmpty
          ? _orderTrackingService.coalesceMonotonicStageSync(
              key,
              apiStage,
              rawStatus: initialStatus,
            )
          : apiStage;
      if (key.isNotEmpty) {
        _orderTrackingService.persistMonotonicIndexAsync(key, apiStage);
      }
      if (!mounted) return;
      setState(() {
        _deliveryAddress = notificationAddress ??
            prefs.getString('delivery_address') ??
            'Address not available';
        _contactNumber = notificationContact ??
            prefs.getString('userPhoneNumber') ??
            'Contact not available';
        _deliveryOption = notificationDeliveryOption ??
            prefs.getString('delivery_option') ??
            'Standard Delivery';
        _orderStatus = initialStatus;
        _timelineStage = initialStage;
        _isLoading = false;
      });

      // Fetch latest order status from API so delivery progression timeline can move
      if (isLoggedIn) {
        await _fetchOrderDetailsFromAPI();
      }

      debugPrint('🔍 Final delivery info loaded:');
      debugPrint('🔍 Address: $_deliveryAddress');
      debugPrint('🔍 Contact: $_contactNumber');
      debugPrint('🔍 Option: $_deliveryOption');
    } catch (e) {
      debugPrint('Error loading delivery info: $e');
      setState(() {
        _deliveryAddress = 'Address not available';
        _contactNumber = 'Contact not available';
        _deliveryOption = 'Standard Delivery';
        _orderStatus =
            widget.orderDetails['status']?.toString() ?? 'Processing';
        _isLoading = false;
      });
    }
  }

  // Load delivery fee from SharedPreferences if it was stored when order was placed
  Future<void> _loadStoredDeliveryFee() async {
    try {
      final transactionId = widget.orderDetails['transaction_id']?.toString() ??
          widget.orderDetails['delivery_id']?.toString() ??
          widget.orderDetails['order_id']?.toString();

      if (transactionId == null || transactionId.isEmpty) {
        debugPrint('🔍 Cannot load stored delivery fee: no transaction_id');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Try with the transaction_id/delivery_id as-is (could be ECL format)
      String deliveryFeeKey = 'order_delivery_fee_$transactionId';
      String totalKey = 'order_total_$transactionId';

      double? storedDeliveryFee = prefs.getDouble(deliveryFeeKey);
      double? storedTotal = prefs.getDouble(totalKey);

      // If not found and transactionId is ECL format, also try with ORDER_ prefix
      // (in case it was stored with ORDER_ prefix from confirmation page)
      if (storedDeliveryFee == null && transactionId.startsWith('ECL')) {
        // Extract the numeric part from ECL format (timestamp + random chars)
        final eclNumericPart = transactionId.replaceFirst('ECL', '');
        // Try to find ORDER_ prefixed version by checking all keys
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith('order_delivery_fee_ORDER_')) {
            // Extract numeric part from ORDER_ key
            final orderNumericPart =
                key.replaceFirst('order_delivery_fee_ORDER_', '');
            // Try matching with different lengths (ECL might have shorter timestamp)
            // Match if ORDER_ timestamp starts with ECL timestamp (or vice versa)
            final minLength = eclNumericPart.length < orderNumericPart.length
                ? eclNumericPart.length
                : orderNumericPart.length;
            if (minLength >= 10) {
              // Try matching first 10 digits (common timestamp length)
              final eclPrefix =
                  eclNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              final orderPrefix = orderNumericPart.substring(
                  0, minLength > 10 ? 10 : minLength);
              if (eclPrefix == orderPrefix) {
                deliveryFeeKey = key;
                storedDeliveryFee = prefs.getDouble(key);
                debugPrint(
                    '🔍 Found delivery fee with ORDER_ prefix: $key (matched by timestamp prefix)');
                break;
              }
            }
          }
        }
      }

      // If still not found, try the reverse: if we have ORDER_ prefix, try ECL format
      if (storedDeliveryFee == null && transactionId.startsWith('ORDER_')) {
        final orderNumericPart = transactionId.replaceFirst('ORDER_', '');
        // Try to find ECL format by searching for keys with matching timestamp prefix
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith('order_delivery_fee_ECL')) {
            // Extract numeric part from ECL key
            final eclNumericPart =
                key.replaceFirst('order_delivery_fee_ECL', '');
            // Try matching with different lengths
            final minLength = eclNumericPart.length < orderNumericPart.length
                ? eclNumericPart.length
                : orderNumericPart.length;
            if (minLength >= 10) {
              // Try matching first 10 digits (common timestamp length)
              final eclPrefix =
                  eclNumericPart.substring(0, minLength > 10 ? 10 : minLength);
              final orderPrefix = orderNumericPart.substring(
                  0, minLength > 10 ? 10 : minLength);
              if (eclPrefix == orderPrefix) {
                deliveryFeeKey = key;
                storedDeliveryFee = prefs.getDouble(key);
                debugPrint(
                    '🔍 Found delivery fee with ECL format: $key (matched by timestamp prefix)');
                break;
              }
            }
          }
        }
      }

      if (storedDeliveryFee != null && storedDeliveryFee > 0) {
        debugPrint(
            '🔍 ✅ Found stored delivery fee: $storedDeliveryFee for order $transactionId');
        // Also get the total if available
        if (storedTotal == null) {
          totalKey = deliveryFeeKey.replaceFirst(
              'order_delivery_fee_', 'order_total_');
          storedTotal = prefs.getDouble(totalKey);
        }

        if (mounted) {
          setState(() {
            _actualDeliveryFee = storedDeliveryFee;
            if (storedTotal != null && storedTotal > 0) {
              _actualTotalAmount = storedTotal;
            }
          });
        }
      } else {
        debugPrint('🔍 No stored delivery fee found for order $transactionId');
        debugPrint('🔍 Tried key: $deliveryFeeKey');
      }
    } catch (e) {
      debugPrint('🔍 Error loading stored delivery fee: $e');
    }
  }

  Future<void> _fetchOrderDetailsFromAPI() async {
    try {
      final details =
          await _orderTrackingService.fetchPageDetails(widget.orderDetails);
      if (!mounted) return;
      _applyPageDetails(details);
    } catch (e) {
      debugPrint('🔍 Error fetching order details from API: $e');
    }
  }

  Future<void> _applyPageDetails(OrderTrackingPageDetails details) async {
    if (!mounted) return;

    if (details.orderItems.isNotEmpty) {
      _applyResolvedItems(details.orderItems);
    }

    if (details.actualDeliveryFee != null && details.actualDeliveryFee! > 0) {
      setState(() {
        _actualDeliveryFee = details.actualDeliveryFee;
        if (details.actualTotalAmount != null) {
          _actualTotalAmount = details.actualTotalAmount;
        }
      });
    }

    if (details.deliveryAddress != null &&
        details.deliveryAddress!.isNotEmpty &&
        _deliveryAddress == 'Address not available') {
      setState(() => _deliveryAddress = details.deliveryAddress);
    }

    if (details.contactNumber != null &&
        details.contactNumber!.isNotEmpty &&
        _contactNumber == 'Contact not available') {
      setState(() => _contactNumber = details.contactNumber);
    }

    if (details.deliveryOption != null &&
        details.deliveryOption!.isNotEmpty &&
        _deliveryOption == 'Standard Delivery') {
      setState(() => _deliveryOption = details.deliveryOption);
    }

    if (details.orderStatus != null &&
        details.orderStatus!.isNotEmpty) {
      final key = _orderStorageKey();
      final apiStage =
          _orderTrackingService.normalizeStage(details.orderStatus);
      final displayStage = key.isNotEmpty
          ? _orderTrackingService.coalesceMonotonicStageSync(
              key,
              apiStage,
              rawStatus: details.orderStatus,
            )
          : apiStage;
      if (key.isNotEmpty) {
        _orderTrackingService.persistMonotonicIndexAsync(key, apiStage);
      }
      if (!mounted) return;
      setState(() {
        _orderStatus = details.orderStatus;
        _timelineStage = displayStage;
        if (details.stageTimes.isNotEmpty) {
          _stageTimes = details.stageTimes;
        }
        if (details.placedAt != null) {
          _placedAt = details.placedAt;
        }
      });
      debugPrint('🔍 Updated order status from API: ${details.orderStatus}');
    } else if (details.stageTimes.isNotEmpty || details.placedAt != null) {
      setState(() {
        if (details.stageTimes.isNotEmpty) {
          _stageTimes = details.stageTimes;
        }
        if (details.placedAt != null) {
          _placedAt = details.placedAt;
        }
      });
    }

    if (!details.foundInOrdersList) {
      debugPrint('🔍 Target order not found in GET /orders list');
    }
  }

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(url);
  }

  List<Map<String, dynamic>> _extractItemsList(Map<String, dynamic> source) =>
      extractOrderItemsList(source);

  void _applyResolvedItems(List<Map<String, dynamic>> candidate) {
    if (candidate.isEmpty || !mounted) return;
    final existing = _resolvedOrderItems ?? _extractItemsList(widget.orderDetails);
    final next = candidate.length >= existing.length ? candidate : existing;
    if (next.length == existing.length && _resolvedOrderItems != null) {
      return;
    }
    setState(() => _resolvedOrderItems = next);
  }

  // Helper method to get order items - handles both single and multiple items
  List<Map<String, dynamic>> getOrderItems() {
    if (_resolvedOrderItems != null && _resolvedOrderItems!.isNotEmpty) {
      return _resolvedOrderItems!;
    }
    return _extractItemsList(widget.orderDetails);
  }

  // add up the total quantity of all items
  int getTotalQuantity() {
    return getOrderItems()
        .fold(0, (sum, item) => sum + (item['qty'] ?? 1) as int);
  }

  // Get total amount - use total_price from order if available (includes delivery fee),
  // otherwise calculate from items and add delivery fee
  double getTotalAmount() {
    // Calculate subtotal from items first
    final subtotal = getOrderItems().fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0.0).toDouble();
      final qty = item['qty'] ?? 1;
      return sum + (price * qty);
    });

    // Get discount if any
    final discountValue = widget.orderDetails['discount'] ??
        widget.orderDetails['discount_amount'];
    final discount = discountValue != null
        ? ((discountValue is num)
            ? discountValue.toDouble()
            : (double.tryParse(discountValue.toString()) ?? 0.0))
        : 0.0;

    // Get delivery fee from order details
    final deliveryFeeValue = widget.orderDetails['delivery_fee'] ??
        widget.orderDetails['deliveryFee'] ??
        widget.orderDetails['delivery_fee_amount'] ??
        widget.orderDetails['shipping_fee'] ??
        widget.orderDetails['shippingFee'];
    double deliveryFee = 0.0;
    if (deliveryFeeValue != null) {
      deliveryFee = (deliveryFeeValue is num)
          ? deliveryFeeValue.toDouble()
          : (double.tryParse(deliveryFeeValue.toString()) ?? 0.0);
    }

    // Try to use total_price/total_amount/amount from order details
    final orderTotalPrice = widget.orderDetails['total_price'] ??
        widget.orderDetails['total_amount'] ??
        widget.orderDetails['amount'];

    if (orderTotalPrice != null) {
      final totalFromOrder = (orderTotalPrice is num)
          ? orderTotalPrice.toDouble()
          : (double.tryParse(orderTotalPrice.toString()) ?? 0.0);

      if (totalFromOrder > 0) {
        // Check if totalFromOrder equals subtotal exactly (within 0.01 tolerance)
        // This means the API only returned subtotal, not the total with delivery fee
        final isSubtotalOnly = (totalFromOrder - subtotal).abs() < 0.01;

        if (isSubtotalOnly && deliveryFee <= 0.01) {
          // total_price is just subtotal, and no delivery fee in order details
          // Check if we fetched actual total/delivery fee from API
          if (_actualTotalAmount != null && _actualTotalAmount! > subtotal) {
            debugPrint(
                '🔍 getTotalAmount: Using actual total fetched from API: $_actualTotalAmount');
            return _actualTotalAmount!;
          }
          if (_actualDeliveryFee != null && _actualDeliveryFee! > 0) {
            final calculatedTotal = subtotal + _actualDeliveryFee! - discount;
            debugPrint(
                '🔍 getTotalAmount: Using delivery fee fetched from API: $_actualDeliveryFee, total: $calculatedTotal');
            return calculatedTotal;
          }

          // total_price is just subtotal, and no delivery fee in order details
          // This means delivery fee is missing from API response
          debugPrint(
              '🔍 getTotalAmount: ⚠️ total_price ($totalFromOrder) equals subtotal ($subtotal) - delivery fee missing from API');
          debugPrint(
              '🔍 getTotalAmount: Returning subtotal only (delivery fee not available): $subtotal');
          return subtotal;
        } else if (isSubtotalOnly && deliveryFee > 0.01) {
          // total_price is subtotal, but we have delivery fee from order details
          final correctedTotal = totalFromOrder + deliveryFee - discount;
          debugPrint(
              '🔍 getTotalAmount: total_price is subtotal only. Adding delivery fee: $totalFromOrder + $deliveryFee - $discount = $correctedTotal');
          return correctedTotal;
        } else if (totalFromOrder > subtotal + 0.01) {
          // totalFromOrder is greater than subtotal, so it likely includes delivery fee
          debugPrint(
              '🔍 getTotalAmount: Using total_price/total_amount/amount (includes delivery): $totalFromOrder');
          return totalFromOrder;
        } else {
          // Use totalFromOrder as is (might be less than subtotal due to discount)
          debugPrint(
              '🔍 getTotalAmount: Using total_price/total_amount/amount: $totalFromOrder');
          return totalFromOrder;
        }
      }
    }

    // Fallback: calculate total from subtotal + delivery fee - discount
    final calculatedTotal = subtotal + deliveryFee - discount;
    debugPrint(
        '🔍 getTotalAmount: Calculated total: subtotal $subtotal + deliveryFee $deliveryFee - discount $discount = $calculatedTotal');
    return calculatedTotal;
  }

  // Helper method to format quantity text
  String formatQuantityText(int quantity) {
    return quantity == 1 ? '1 item' : '$quantity items';
  }

  /// Same stage as the timeline — avoids the header card jumping on noisy API status.
  OrderTrackingStage _displayStageForUi(String fallbackStatus) {
    return _timelineStage ??
        _orderTrackingService.normalizeStage(_orderStatus ?? fallbackStatus);
  }

  String _friendlyStageLabel(String fallbackStatus, bool isPickup) {
    var label =
        _orderTrackingService.stageLabel(_displayStageForUi(fallbackStatus));
    if (isPickup) {
      if (label == 'Out for Delivery') label = 'Ready for Pickup';
      if (label == 'Arrived') label = 'At store';
      if (label == 'Delivered') label = 'Picked up';
    }
    return label;
  }

  String _statusBadgeLabel(String fallbackStatus, bool isPickup) {
    var label =
        _orderTrackingService.stageLabel(_displayStageForUi(fallbackStatus));
    if (isPickup) {
      if (label == 'Out for Delivery') return 'Ready for Pickup';
      if (label == 'Arrived') return 'At store';
      if (label == 'Delivered') return 'Picked up';
    }
    return label;
  }

  bool _isDeliveredStatus(String fallbackStatus) {
    return _displayStageForUi(fallbackStatus) == OrderTrackingStage.delivered;
  }

  ({
    double subtotal,
    double deliveryFee,
    double discount,
    double total,
    bool showDeliveryFee,
  }) _billSummary(double totalAmount) {
    final orderItems = getOrderItems();
    final subtotal = orderItems.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0.0).toDouble();
      final qty = item['qty'] ?? 1;
      return sum + (price * qty);
    });

    final discountValue = widget.orderDetails['discount'] ??
        widget.orderDetails['discount_amount'];
    final discount = discountValue != null
        ? ((discountValue is num)
            ? discountValue.toDouble()
            : (double.tryParse(discountValue.toString()) ?? 0.0))
        : 0.0;

    final deliveryFeeValue = widget.orderDetails['delivery_fee'] ??
        widget.orderDetails['deliveryFee'];
    var deliveryFee = 0.0;
    if (deliveryFeeValue != null) {
      deliveryFee = (deliveryFeeValue is num)
          ? deliveryFeeValue.toDouble()
          : (double.tryParse(deliveryFeeValue.toString()) ?? 0.0);
    }
    if (deliveryFee <= 0.01 &&
        _actualDeliveryFee != null &&
        _actualDeliveryFee! > 0.01) {
      deliveryFee = _actualDeliveryFee!;
    }
    if (deliveryFee <= 0.01) {
      final calculated = totalAmount - subtotal + discount;
      if (calculated > 0.01) deliveryFee = calculated;
    }

    return (
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      total: totalAmount,
      showDeliveryFee: deliveryFee > 0.01 && !_isPickupOrder(),
    );
  }

  List<Widget> _trackOrderBody({
    required String status,
    required DateTime? orderDate,
    required List<Map<String, dynamic>> orderItems,
    required double totalAmount,
    required String orderNumber,
    required bool isPickup,
  }) {
    final isDelivered = _isDeliveredStatus(status);
    final bill = _billSummary(totalAmount);
    final trackingItems =
        orderItems.map(OrderTrackingItem.fromMap).toList(growable: false);
    final timelineSteps = OrderTrackingTimelineHelper.build(
      service: _orderTrackingService,
      currentStatus: status,
      isPickup: isPickup,
      placedAt: _placedAt ?? orderDate,
      stageTimes: _stageTimes,
      displayStage: _timelineStage,
    );
    OrderStepsApiLogger.logBuiltTimeline(
      source: 'track-order page UI',
      rawStatus: status,
      stage: _orderTrackingService.normalizeStage(status),
      steps: timelineSteps,
    );

    final children = <Widget>[
      PostCheckoutDesign.pageLogo(context, height: 30),
      OrderTrackingStatusCard(
        stageLabel: _friendlyStageLabel(status, isPickup),
        badgeLabel: _statusBadgeLabel(status, isPickup),
        orderRef: orderNumber,
        isPickup: isPickup,
        isDelivered: isDelivered,
        accent: _accent,
        placedAt: orderDate,
      ),
    ];

    if (!isDelivered) {
      children.addAll([
        const SizedBox(height: 12),
        PostCheckoutOrderProgressCard(
          steps: timelineSteps,
          accent: _accent,
          animate: false,
        ),
      ]);
    }

    if (trackingItems.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 12),
        PostCheckoutOrderItemsCard(
          items: trackingItems,
          accent: _accent,
          showAllItems: true,
          animate: false,
        ),
      ]);
    }

    children.addAll([
      const SizedBox(height: 12),
      OrderTrackingBillCard(
        subtotal: bill.subtotal,
        deliveryFee: bill.deliveryFee,
        discount: bill.discount,
        total: bill.total,
        accent: _accent,
        showDeliveryFee: bill.showDeliveryFee,
      ),
      const SizedBox(height: 12),
      OrderTrackingDeliveryCard(
        isPickup: isPickup,
        address: isPickup
            ? _pickupLocationSummary()
            : (_deliveryAddress ?? 'Not available'),
        contact: _contactNumber ?? 'Not available',
        method: isPickup
            ? 'Store pickup'
            : (_deliveryOption ?? 'Standard delivery'),
        accent: _accent,
      ),
    ]);

    return children;
  }

  @override
  Widget build(BuildContext context) {
    try {
      debugPrint('🔍 OrderTrackingPage build method called');
      debugPrint('🔍 Order details: ${widget.orderDetails}');

      final orderDate =
          parseOrderTimestamp(widget.orderDetails['created_at']);
      final status =
          _orderStatus ?? widget.orderDetails['status'] ?? 'Processing';
      final orderItems = getOrderItems();
      final totalQuantity = getTotalQuantity();
      final totalAmount = getTotalAmount();
      final orderNumber = widget.orderDetails['order_number']?.toString() ??
          widget.orderDetails['delivery_id']?.toString() ??
          widget.orderDetails['transaction_id']?.toString() ??
          widget.orderDetails['order_id']?.toString() ??
          widget.orderDetails['id']?.toString() ??
          'N/A';
      final isPickup = _isPickupOrder();

      debugPrint('🔍 Order date: $orderDate');
      debugPrint('🔍 Status: $status');
      debugPrint('🔍 Total quantity: $totalQuantity');
      debugPrint('🔍 Total amount: $totalAmount');

      return Scaffold(
        backgroundColor: PostCheckoutDesign.pageBg(context),
        body: _isLoading
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  EclExpandableSliverAppBar(
                    toolbarTitle: _sliverHeaderOrderLabel(),
                    heroTitle: _sliverHeaderOrderLabel(),
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AppBackButton(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        iconColor: Colors.white,
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        },
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CartIconButton(
                            iconColor: Colors.white,
                            iconSize: 22,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_accent),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Fetching your order…',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hang tight',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: _loadDeliveryInfo,
                color: _accent,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    EclExpandableSliverAppBar(
                      toolbarTitle: _sliverHeaderOrderLabel(),
                      heroTitle: _sliverHeaderOrderLabel(),
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AppBackButton(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          iconColor: Colors.white,
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/', (route) => false);
                            }
                          },
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CartIconButton(
                              iconColor: Colors.white,
                              iconSize: 22,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        10,
                        14,
                        28 + MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _trackOrderBody(
                            status: status,
                            orderDate: orderDate,
                            orderItems: orderItems,
                            totalAmount: totalAmount,
                            orderNumber: orderNumber,
                            isPickup: isPickup,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );
    } catch (e) {
      debugPrint('🔍 Error in OrderTrackingPage build: $e');
      return Scaffold(
        backgroundColor: PostCheckoutDesign.pageBg(context),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            EclExpandableSliverAppBar(
              toolbarTitle: _sliverHeaderOrderLabel(),
              heroTitle: _sliverHeaderOrderLabel(),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error loading order tracking',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Error: $e',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
