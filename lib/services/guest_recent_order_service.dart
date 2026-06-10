import '../models/cart_item.dart';
import '../models/guest_recent_order.dart';
import '../models/order_tracking_model.dart';
import '../repositories/guest_recent_order_repository.dart';
import '../services/auth_service.dart';

/// Saves and restores the latest guest order for in-app tracking.
class GuestRecentOrderService {
  GuestRecentOrderService._([GuestRecentOrderRepository? repository])
      : _repository = repository ?? GuestRecentOrderRepositoryImpl();

  static final GuestRecentOrderService instance = GuestRecentOrderService._();

  final GuestRecentOrderRepository _repository;

  Future<String?> _currentGuestId() => AuthService.getToken();

  Future<bool> hasRecentOrder() async {
    final order = await loadRecentOrder();
    return order != null;
  }

  Future<GuestRecentOrder?> loadRecentOrder() async {
    if (await AuthService.isLoggedIn()) return null;
    final guestId = await _currentGuestId();
    if (guestId == null || guestId.isEmpty) return null;
    return _repository.loadForGuest(guestId);
  }

  Future<void> saveFromCheckoutSnapshot({
    required Map<String, dynamic> paymentParams,
    required List<CartItem> purchasedItems,
    required String initialTransactionId,
    required String paymentMethod,
    String deliveryAddress = '',
    String contactNumber = '',
    String deliveryOption = 'delivery',
    String estimatedDeliveryTime = '',
    double? deliveryFee,
    double discount = 0,
    String initialStatus = 'pending',
  }) async {
    if (await AuthService.isLoggedIn()) return;
    final guestId = await _currentGuestId();
    if (guestId == null || guestId.isEmpty) return;
    if (initialTransactionId.isEmpty) return;

    final snapshot = GuestRecentOrder(
      guestId: guestId,
      initialTransactionId: initialTransactionId,
      paymentParams: Map<String, dynamic>.from(paymentParams),
      purchasedItems: purchasedItems.map((item) => item.toJson()).toList(),
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
      contactNumber: contactNumber,
      deliveryOption: deliveryOption,
      estimatedDeliveryTime: estimatedDeliveryTime,
      deliveryFee: deliveryFee,
      discount: discount,
      initialStatus: initialStatus,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.save(snapshot);
  }

  Future<void> saveFromOrderTracking({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) async {
    if (await AuthService.isLoggedIn()) return;
    final guestId = await _currentGuestId();
    if (guestId == null || guestId.isEmpty) return;

    final snapshot = GuestRecentOrder.fromOrderTracking(
      order: order,
      guestId: guestId,
      initialTransactionId: initialTransactionId,
    );
    await _repository.save(snapshot);
  }

  Future<void> clearForCurrentGuest() async {
    final guestId = await _currentGuestId();
    if (guestId == null || guestId.isEmpty) return;
    await _repository.clearForGuest(guestId);
  }
}
