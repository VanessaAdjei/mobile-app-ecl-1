import '../database/guest_order/guest_recent_order_local_storage.dart';
import '../models/guest_recent_order.dart';

abstract class GuestRecentOrderRepository {
  Future<GuestRecentOrder?> loadForGuest(String guestId);
  Future<void> save(GuestRecentOrder order);
  Future<void> clearForGuest(String guestId);
}

class GuestRecentOrderRepositoryImpl implements GuestRecentOrderRepository {
  GuestRecentOrderRepositoryImpl([GuestRecentOrderLocalStorage? localStorage])
      : _localStorage = localStorage ?? GuestRecentOrderLocalStorageImpl();

  final GuestRecentOrderLocalStorage _localStorage;

  @override
  Future<GuestRecentOrder?> loadForGuest(String guestId) async {
    final raw = await _localStorage.readForGuest(guestId);
    if (raw == null) return null;
    final order = GuestRecentOrder.fromJson(raw);
    if (order.guestId != guestId || order.initialTransactionId.isEmpty) {
      return null;
    }
    return order;
  }

  @override
  Future<void> save(GuestRecentOrder order) async {
    if (order.guestId.isEmpty || order.initialTransactionId.isEmpty) return;
    await _localStorage.writeForGuest(order.guestId, order.toJson());
  }

  @override
  Future<void> clearForGuest(String guestId) {
    return _localStorage.clearForGuest(guestId);
  }
}
