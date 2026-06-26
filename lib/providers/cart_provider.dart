// providers/cart_provider.dart
import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../models/category_fetch_result.dart';
import '../services/realtime_cart_sync_service.dart';
import '../services/guest_checkout_draft_service.dart';

class CartProvider with ChangeNotifier {
  static const Duration _cartHttpTimeout = Duration(seconds: 12);

  final CartService _cartService = CartService();

  // In-memory cart for the current session (server is source of truth).
  List<CartItem> _cartItems = [];
  List<CartItem> _purchasedItems = [];
  String? _currentUserId;
  bool _isDisposed = false;

  /// Blocks background/full cart fetch while a delete is in flight (avoids re-adding rows).
  bool _inhibitRemoteCartSync = false;
  int _remoteSyncHeldUntilMs = 0;

  bool get _remoteSyncPaused {
    if (_inhibitRemoteCartSync) return true;
    return DateTime.now().millisecondsSinceEpoch < _remoteSyncHeldUntilMs;
  }

  void _holdRemoteCartSync([Duration hold = const Duration(seconds: 5)]) {
    final until = DateTime.now().millisecondsSinceEpoch + hold.inMilliseconds;
    if (until > _remoteSyncHeldUntilMs) {
      _remoteSyncHeldUntilMs = until;
    }
  }

  String? _pendingOriginalProductId;
  String? _pendingItemName;
  String? _pendingItemBatch;

  void _logCartApiResponse({
    required String label,
    required String url,
    Map<String, String>? headers,
    String? requestBody,
    required CategoryFetchResult result,
  }) {
    _cartService.logCartApiResponse(
      label: label,
      url: url,
      headers: headers,
      requestBody: requestBody,
      result: result,
    );
  }

  String _normalizeProductName(String name) {
    return CartProvider.normalizeProductName(name);
  }

  /// Public helper so item detail and others can match cart items by name (e.g. "E-Panol" vs "E Panol").
  static String normalizeProductName(String name) {
    var normalized = name.toLowerCase().trim().replaceAll('-', ' ');
    normalized = normalized.replaceAll(RegExp(r'[()[\].,]'), ' ');
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return words.join(' ');
  }

  static bool productNamesLooselyMatch(String a, String b) {
    final na = normalizeProductName(a);
    final nb = normalizeProductName(b);
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    final wordsA = na.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = nb.split(' ').where((w) => w.length > 2).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return false;
    final common = wordsA.intersection(wordsB).length;
    return common >= 2 || (common >= 1 && wordsA.first == wordsB.first);
  }

  bool _productNamesLooselyMatch(String a, String b) =>
      productNamesLooselyMatch(a, b);

  /// Same rules as [_sameCartProduct] — used by UI selectors and cart lookups.
  static bool linesMatchSku(
    CartItem line, {
    required String productName,
    required String batchNo,
    String? catalogProductId,
  }) {
    if (line.batchNo.isNotEmpty &&
        batchNo.isNotEmpty &&
        line.batchNo != batchNo) {
      return false;
    }
    if (productNamesLooselyMatch(productName, line.name)) {
      return true;
    }
    final probeId = catalogProductId?.trim() ?? '';
    if (probeId.isNotEmpty) {
      final lineId = line.originalProductId ?? line.productId;
      if (lineId.isNotEmpty && lineId == probeId) {
        return true;
      }
    }
    return false;
  }

  static CartItem? findLineForSku(
    CartProvider cart, {
    required String productName,
    required String batchNo,
    String? catalogProductId,
  }) {
    final index = findLineIndexForSku(
      cart,
      productName: productName,
      batchNo: batchNo,
      catalogProductId: catalogProductId,
    );
    if (index == -1) return null;
    return cart.cartItems[index];
  }

  static int findLineIndexForSku(
    CartProvider cart, {
    required String productName,
    required String batchNo,
    String? catalogProductId,
  }) {
    for (var i = 0; i < cart.cartItems.length; i++) {
      if (linesMatchSku(
        cart.cartItems[i],
        productName: productName,
        batchNo: batchNo,
        catalogProductId: catalogProductId,
      )) {
        return i;
      }
    }
    return -1;
  }

  bool _sameCartProduct(CartItem a, CartItem b) {
    return linesMatchSku(
      a,
      productName: b.name,
      batchNo: b.batchNo,
      catalogProductId: b.originalProductId ?? b.productId,
    );
  }

  void _consolidateDuplicateCartLines() {
    final merged = <String, CartItem>{};
    for (final item in _cartItems) {
      final key =
          '${_normalizeProductName(item.name)}|${item.batchNo.trim().toLowerCase()}';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = item;
      } else {
        final primary = hasServerCartLineId(existing.id)
            ? existing
            : (hasServerCartLineId(item.id) ? item : existing);
        final secondary = identical(primary, existing) ? item : existing;
        merged[key] = primary.copyWith(
          quantity: primary.quantity + secondary.quantity,
          totalPrice: primary.totalPrice + secondary.totalPrice,
          id: primary.id.isNotEmpty ? primary.id : secondary.id,
          serverProductId: primary.serverProductId ?? secondary.serverProductId,
          originalProductId:
              primary.originalProductId ?? secondary.originalProductId,
        );
      }
    }
    if (merged.length != _cartItems.length) {
      _cartItems = merged.values.toList();
      notifyListeners();
    }
  }

  bool _isCheckAuthSuccess(Map<String, dynamic>? data) {
    if (data == null) return false;
    final added = data['added']?.toString().toLowerCase() ?? '';
    return data['status']?.toString() == 'success' || added.contains('updated');
  }

  /// Completed / historical rows must not affect the live cart UI.
  static bool _isActiveCartServerLine(Map<String, dynamic> raw) {
    final status = raw['status']?.toString().trim().toLowerCase() ?? '';
    if (status.isEmpty) return true;
    const inactive = {
      'order placed',
      'delivered',
      'completed',
      'cancelled',
      'canceled',
    };
    return !inactive.contains(status);
  }

  List<dynamic> _activeServerCartItems(List<dynamic>? items) {
    if (items == null) return const [];
    return items
        .where(
          (raw) =>
              raw is Map &&
              _isActiveCartServerLine(Map<String, dynamic>.from(raw)),
        )
        .toList();
  }

  /// Local cart qty/price/ids come only from check-auth `items` (field `qty`).
  bool _applyCheckAuthCartResponse(
    Map<String, dynamic>? data, {
    CartItem? productHint,
    bool wasDecrease = false,
  }) {
    if (!_isCheckAuthSuccess(data)) return false;

    final items = _activeServerCartItems(data!['items'] as List? ?? []);
    if (items.isNotEmpty) {
      if (productHint != null) {
        _pendingOriginalProductId =
            productHint.originalProductId ?? productHint.productId;
        _pendingItemName = productHint.name;
        _pendingItemBatch = productHint.batchNo;
      }
      _mergeFullServerCartFromCheckAuthItems(items);
      return true;
    }

    if (wasDecrease && productHint != null) {
      _cartItems.removeWhere((line) => _sameCartProduct(line, productHint));
      notifyListeners();
      return true;
    }

    return true;
  }

  /// Replaces local cart with the full `items` list from check-auth (server is billing source).
  void _mergeFullServerCartFromCheckAuthItems(List<dynamic> serverItems) {
    final activeItems = _activeServerCartItems(serverItems);
    if (activeItems.isEmpty) return;

    final mergedItems = <String, CartItem>{};
    for (final raw in activeItems) {
      if (raw is! Map) continue;
      var cartItem = CartItem.fromServerJson(Map<String, dynamic>.from(raw));
      final mergeKey =
          '${_normalizeProductName(cartItem.name)}-${cartItem.batchNo}';

      if (mergedItems.containsKey(mergeKey)) {
        final existing = mergedItems[mergeKey]!;
        mergedItems[mergeKey] = existing.copyWith(
          quantity: existing.quantity + cartItem.quantity,
          totalPrice: existing.totalPrice + cartItem.totalPrice,
        );
      } else {
        mergedItems[mergeKey] = cartItem;
      }
    }

    if (mergedItems.isEmpty) return;

    final items = mergedItems.values.toList();
    for (var i = 0; i < items.length; i++) {
      var cartItem = items[i];
      CartItem? matchingLocal;
      for (final local in _cartItems) {
        if (_sameCartProduct(local, cartItem)) {
          matchingLocal = local;
          break;
        }
      }
      if (matchingLocal != null) {
        cartItem = cartItem.copyWith(
          originalProductId:
              matchingLocal.originalProductId ?? matchingLocal.productId,
          image: matchingLocal.image.isNotEmpty
              ? matchingLocal.image
              : cartItem.image,
        );
      } else if (_pendingItemBatch != null &&
          cartItem.batchNo == _pendingItemBatch &&
          (_pendingItemName == null ||
              _productNamesLooselyMatch(cartItem.name, _pendingItemName!))) {
        cartItem = cartItem.copyWith(
          originalProductId: _pendingOriginalProductId,
        );
      }
      items[i] = cartItem;
    }

    _pendingOriginalProductId = null;
    _pendingItemName = null;
    _pendingItemBatch = null;

    _cartItems = items;
    _consolidateDuplicateCartLines();
    debugPrint(
      '✅ Cart updated from check-auth (${_cartItems.length} line(s), '
      'subtotal ${_cartItems.fold<double>(0, (s, i) => s + i.totalPrice).toStringAsFixed(2)})',
    );
    notifyListeners();
  }

  /// True when [id] is a server line id (not empty / not a local timestamp id).
  static bool hasServerCartLineId(String id) {
    if (id.isEmpty) return false;
    if (id.length >= 13 && RegExp(r'^1\d{12,}$').hasMatch(id)) return false;
    return true;
  }

  List<CartItem> get cartItems => _cartItems;
  List<CartItem> get purchasedItems => _purchasedItems;
  String? get currentUserId => _currentUserId;

  CartProvider() {
    _initializeCart();
    _initializeRealtimeSync();
  }

  Future<void> _initializeCart() async {
    await _clearLegacyLocalCartStorage();
    await _checkCurrentUser();
    await syncWithApi();
  }

  /// Removes deprecated on-device cart cache (`user_carts`).
  Future<void> _clearLegacyLocalCartStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('user_carts')) {
        await prefs.remove('user_carts');
        debugPrint('🛒 Removed legacy local cart storage (user_carts)');
      }
    } catch (e) {
      debugPrint('🛒 Could not clear legacy cart storage: $e');
    }
  }

  Future<void> _initializeRealtimeSync() async {
    try {
      await RealtimeCartSyncService().initialize(this);
      debugPrint('🔄 CartProvider: Background cart sync started');
      if (_cartItems.isNotEmpty) {
        _scheduleBackgroundCartSync();
      }
    } catch (e) {
      debugPrint(
          '🔄 CartProvider: Error initializing background cart sync: $e');
    }
  }

  void _scheduleBackgroundCartSync() {
    if (_isDisposed) return;
    unawaited(RealtimeCartSyncService().triggerImmediateSync());
  }

  Future<void> _checkCurrentUser() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      _currentUserId = (await AuthService.getCurrentUserID()) as String;
      await _loadPurchasedItems();
    } else {
      _currentUserId = null;
      _purchasedItems = [];
    }
    _cartItems = [];
    notifyListeners();
  }

  Future<void> _syncGuestCartFromApi(String guestToken) async {
    final headers = _cartAuthHeaders(guestToken, false);
    final response = await _cartService.fetchCartSnapshot(headers: headers);
    if (!CartService.isSuccessStatus(response.statusCode)) {
      debugPrint(
        '⚠️ Guest cart sync failed: status ${response.statusCode}',
      );
      return;
    }

    final data = CartService.decodeBody(response);
    if (data == null) return;

    final rawItems = data['items'] as List? ?? data['cart_items'] as List?;
    if (rawItems == null) return;

    if (rawItems.isEmpty) {
      _cartItems = [];
      notifyListeners();
      return;
    }

    _mergeFullServerCartFromCheckAuthItems(rawItems);
  }

  Future<void> syncWithApi() async {
    if (_remoteSyncPaused) {
      debugPrint('⏸️ Cart sync skipped (local cart mutation in progress)');
      return;
    }
    try {
      final auth = await _resolveCartAuth();
      if (auth.token == null) return;

      if (!auth.isLoggedIn) {
        await _syncGuestCartFromApi(auth.token!);
        return;
      }

      final hashedLink = await AuthService.getHashedLink();
      if (hashedLink == null || hashedLink.isEmpty) return;

      final response = await _cartService.fetchLoggedInCart(
        hashedLink: hashedLink,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Accept': 'application/json',
        },
        timeout: const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = CartService.decodeBody(response);
        if (data == null) {
          debugPrint('⚠️ Cart sync failed: Could not decode server response');
          return;
        }

        if (data['cart_items'] != null) {
          final rawItems = data['cart_items'] as List;

          if (rawItems.isEmpty) {
            _cartItems = [];
            notifyListeners();
            return;
          }

          // Merge duplicate items from server by name and batch
          Map<String, CartItem> mergedItems = {};

          for (final rawItem in rawItems) {
            var cartItem = CartItem.fromServerJson(rawItem);
            final normalizedName = _normalizeProductName(cartItem.name);
            final mergeKey = '$normalizedName-${cartItem.batchNo}';

            if (mergedItems.containsKey(mergeKey)) {
              // Merge with existing item
              final existingItem = mergedItems[mergeKey]!;
              final newQuantity = existingItem.quantity + cartItem.quantity;
              final newTotalPrice =
                  existingItem.totalPrice + cartItem.totalPrice;

              mergedItems[mergeKey] = existingItem.copyWith(
                quantity: newQuantity,
                totalPrice: newTotalPrice,
              );
            } else {
              // First occurrence of this item
              mergedItems[mergeKey] = cartItem;
            }
          }

          List<CartItem> items = mergedItems.values.toList();

          // Preserve original product IDs from local items
          for (int i = 0; i < items.length; i++) {
            var cartItem = items[i];

            CartItem? matchingLocalItem;
            try {
              matchingLocalItem = _cartItems.firstWhere(
                (localItem) => _sameCartProduct(localItem, cartItem),
              );
            } catch (e) {
              matchingLocalItem = null;
            }

            // If we found a matching local item, preserve its original product ID
            if (matchingLocalItem != null) {
              cartItem = cartItem.copyWith(
                originalProductId: matchingLocalItem.originalProductId ??
                    matchingLocalItem.productId,
              );
            } else {
              // Check if this is the pending item we're trying to preserve
              bool isPendingItem = _pendingItemBatch != null &&
                  cartItem.batchNo == _pendingItemBatch &&
                  (_pendingItemName == null ||
                      _productNamesLooselyMatch(
                          cartItem.name, _pendingItemName!));

              if (isPendingItem) {
                cartItem = cartItem.copyWith(
                  originalProductId: _pendingOriginalProductId,
                );

                // Clear pending variables after use
                _pendingOriginalProductId = null;
                _pendingItemName = null;
                _pendingItemBatch = null;
              } else {
                // Try more flexible matching for e-panol products
                CartItem? flexibleMatchingLocalItem;
                try {
                  flexibleMatchingLocalItem = _cartItems.firstWhere(
                    (localItem) {
                      final localNormalizedName =
                          _normalizeProductName(localItem.name);
                      final serverNormalizedName =
                          _normalizeProductName(cartItem.name);

                      // More flexible matching for e-panol products
                      final isEpanolLocal =
                          localNormalizedName.contains('e panol') ||
                              localNormalizedName.contains('e-panol');
                      final isEpanolServer =
                          serverNormalizedName.contains('e panol') ||
                              serverNormalizedName.contains('e-panol');

                      if (isEpanolLocal && isEpanolServer) {
                        // For e-panol products, match by batch number and flavor
                        final localHasStrawberry =
                            localNormalizedName.contains('strawberry');
                        final serverHasStrawberry =
                            serverNormalizedName.contains('strawberry');
                        final localHasOriginal =
                            localNormalizedName.contains('original');
                        final serverHasOriginal =
                            serverNormalizedName.contains('original');

                        return localItem.batchNo == cartItem.batchNo &&
                            ((localHasStrawberry && serverHasStrawberry) ||
                                (localHasOriginal && serverHasOriginal));
                      }

                      return false;
                    },
                  );
                } catch (e) {
                  flexibleMatchingLocalItem = null;
                }

                if (flexibleMatchingLocalItem != null) {
                  cartItem = cartItem.copyWith(
                    originalProductId:
                        flexibleMatchingLocalItem.originalProductId ??
                            flexibleMatchingLocalItem.productId,
                  );
                } else {
                  debugPrint('🔍 NO LOCAL ITEM FOUND FOR PRESERVATION ===');
                  debugPrint('Product: ${cartItem.name}');
                  debugPrint('Batch: ${cartItem.batchNo}');
                  debugPrint('Server Product ID: ${cartItem.productId}');
                  debugPrint('==========================================');
                }
              }
            }

            items[i] = cartItem;
          }

          _cartItems = items;
          _consolidateDuplicateCartLines();

          notifyListeners();
        } else {
          debugPrint(
              '⚠️ Cart sync failed: Missing "cart_items" in server response');
          debugPrint('Response body: ${response.rawBody}');
        }
      } else {
        debugPrint(
            '⚠️ Cart sync failed: Server returned status code ${response.statusCode}');
        if (response.statusCode >= 400) {
          debugPrint('Response body: ${response.rawBody}');
        }
      }
    } catch (e) {
      debugPrint('Cart sync error: $e');
    }
  }

  Future<void> addToCart(CartItem item) async {
    debugPrint('🚀 ADD TO CART: ${item.name} (qty ${item.quantity})');

    _currentUserId ??= await AuthService.getCurrentUserID();

    // Update UI immediately; reconcile with check-auth response below.
    await _addToLocalCart(item);

    try {
      final auth = await _resolveCartAuth();
      if (auth.token == null) {
        debugPrint('No auth token — cannot save cart to server');
        return;
      }

      _inhibitRemoteCartSync = true;
      _holdRemoteCartSync(const Duration(seconds: 5));
      try {
        final line = _cartItems.firstWhere((c) => _sameCartProduct(c, item));
        final synced = await _syncAddToServer(
          line,
          quantity: line.quantity,
          token: auth.token!,
          isLoggedIn: auth.isLoggedIn,
        );
        if (!synced) {
          _showSyncError(
            'Could not add to cart on server. The product may be unavailable.',
          );
          if (!_remoteSyncPaused) {
            await syncWithApi();
          }
        }
      } finally {
        _inhibitRemoteCartSync = false;
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  /// POST /check-auth; local cart is updated only from the response `items`.
  Future<bool> _syncAddToServer(
    CartItem item, {
    required int quantity,
    String? token,
    bool? isLoggedIn,
  }) async {
    try {
      final auth = token != null && isLoggedIn != null
          ? (token: token, isLoggedIn: isLoggedIn)
          : await _resolveCartAuth();
      if (auth.token == null) {
        debugPrint('Cannot sync add to server — missing auth token');
        return false;
      }

      final headers = _cartAuthHeaders(auth.token!, auth.isLoggedIn);
      final candidates = _productIdCandidatesForCheckAuth(item);
      if (candidates.isEmpty) {
        debugPrint('❌ No valid product ID — cannot add to cart');
        return false;
      }

      final qtyToSend = quantity > 0 ? quantity : 1;
      final response = await _cartService.checkAuthWithProductCandidates(
        headers: headers,
        productIds: candidates,
        quantity: qtyToSend,
        batchNo: item.batchNo.isNotEmpty ? item.batchNo : null,
        timeout: _cartHttpTimeout,
        onAttempt: ({
          required String url,
          required Map<String, String> headers,
          required String requestBody,
          required CategoryFetchResult result,
        }) {
          _logCartApiResponse(
            label: 'ADD TO CART API RESPONSE',
            url: url,
            headers: headers,
            requestBody: requestBody,
            result: result,
          );
        },
      );

      if (!CartService.isSuccessStatus(response.statusCode)) {
        debugPrint('Add to cart failed: ${response.statusCode}');
        return false;
      }

      final data = CartService.decodeBody(response);
      return _applyCheckAuthCartResponse(data, productHint: item);
    } catch (e) {
      debugPrint('Error adding/updating cart item on server: $e');
      return false;
    }
  }

  // Optimistic in-memory update until check-auth response arrives.
  Future<void> _addToLocalCart(CartItem item) async {
    // Check if item already exists in local cart by product ID, batch number, and name
    final existingIndex =
        _cartItems.indexWhere((cartItem) => _sameCartProduct(cartItem, item));

    if (existingIndex != -1) {
      // Item exists, add to existing quantity
      final oldQuantity = _cartItems[existingIndex].quantity;
      final newQuantity = oldQuantity + item.quantity;

      debugPrint('🔍 UPDATING LOCAL CART ITEM ===');
      debugPrint('Product: ${item.name}');
      debugPrint('Old Quantity: $oldQuantity');
      debugPrint('Adding Quantity: ${item.quantity}');
      debugPrint('New Total Quantity: $newQuantity');
      debugPrint('==============================');

      _cartItems[existingIndex].updateQuantity(newQuantity);
    } else {
      // Item doesn't exist, add it
      debugPrint('🔍 ADDING NEW ITEM TO LOCAL CART ===');
      debugPrint('Product: ${item.name}');
      debugPrint('Quantity: ${item.quantity}');
      debugPrint('===================================');

      _cartItems.add(item);
    }

    notifyListeners();
  }

  void purchaseItems() async {
    if (_currentUserId == null) return;

    // Only add selected items to purchased items
    final selectedItems = _cartItems.where((item) => item.isSelected).toList();
    _purchasedItems.addAll(selectedItems);

    // Remove selected items from cart (keep unselected items)
    _cartItems.removeWhere((item) => item.isSelected);

    await _savePurchasedItems();
    notifyListeners();
  }

  /// Removes one cart row locally and via POST /remove-from-cart (`cart_id`).
  /// Pass [rowIndex] when the line has no server id yet (empty `cartId`).
  Future<void> removeFromCart(String cartId, {int? rowIndex}) async {
    final itemIndex = _resolveCartLineIndex(cartId, rowIndex: rowIndex);
    if (itemIndex == -1) {
      debugPrint('❌ Item not found in cart with ID: $cartId');
      return;
    }
    final target = _cartItems[itemIndex];

    debugPrint('=== REMOVE FROM CART ===');
    debugPrint('Product: ${target.name}');
    debugPrint('Cart line ID: ${target.id}');
    debugPrint('========================');

    _cartItems.removeAt(itemIndex);
    notifyListeners();

    if (!hasServerCartLineId(target.id)) {
      debugPrint('Local-only cart line removed (no server id yet)');
      return;
    }

    final auth = await _resolveCartAuth();
    if (auth.token == null) return;

    _inhibitRemoteCartSync = true;
    _holdRemoteCartSync(const Duration(seconds: 5));
    try {
      final ok = await _removeCartLineById(
        target.id,
        auth.token!,
        auth.isLoggedIn,
        reason: 'user remove',
      );
      if (!ok && !_remoteSyncPaused) {
        await syncWithApi();
      }
    } catch (e) {
      debugPrint('⚠️ Error removing cart line: $e');
      if (!_remoteSyncPaused) {
        await syncWithApi();
      }
    } finally {
      _inhibitRemoteCartSync = false;
    }
  }

  // Track ongoing quantity updates - using Set for automatic cleanup
  final Set<String> _updatingItemIds = {};

  // Method to check if an item is currently being updated.
  // Pass [rowIndex] so only that row shows the loader when multiple items share the same id.
  bool isItemUpdating(String itemId, [int? rowIndex]) {
    if (rowIndex != null) {
      return _updatingItemIds.contains('${itemId}_$rowIndex');
    }
    return _updatingItemIds.contains(itemId);
  }

  // Method to check if any item is currently being updated
  bool get isAnyItemUpdating => _updatingItemIds.isNotEmpty;

  // Method to get count of items being updated
  int get updatingItemsCount => _updatingItemIds.length;

  // Helper method to manage loader lifecycle automatically
  Future<T> _withLoader<T>(
    String itemId,
    Future<T> Function() operation,
  ) async {
    // Prevent duplicate operations
    if (_updatingItemIds.contains(itemId)) {
      debugPrint('⏳ Update already in progress for item $itemId - skipping...');
      throw StateError('Update already in progress');
    }

    _updatingItemIds.add(itemId);
    notifyListeners();

    try {
      final result = await operation().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Operation timed out');
        },
      );
      return result;
    } finally {
      _updatingItemIds.remove(itemId);
      notifyListeners();
      debugPrint('✅ Loader cleared for item $itemId');
    }
  }

  /// For [Selector] on cart rows — busy state without rebuilding the whole page.
  static bool selectRowIsUpdating(
    CartProvider cart,
    String itemId,
    int rowIndex,
  ) =>
      cart.isItemUpdating(itemId, rowIndex);

  /// +1 on the cart line — POST /check-auth with absolute new qty (current + 1).
  Future<void> incrementCartLine(String itemId, {int? rowIndex}) =>
      _stepCartLineQuantity(itemId, delta: 1, rowIndex: rowIndex);

  /// −1 on the cart line — POST /check-auth with absolute new qty (current − 1).
  Future<void> decrementCartLine(String itemId, {int? rowIndex}) =>
      _stepCartLineQuantity(itemId, delta: -1, rowIndex: rowIndex);

  Future<void> _stepCartLineQuantity(
    String itemId, {
    required int delta,
    int? rowIndex,
  }) async {
    if (delta == 0) return;

    final itemIndex = _resolveCartLineIndex(itemId, rowIndex: rowIndex);
    if (itemIndex == -1) {
      debugPrint('⚠️ Item not found with ID: $itemId');
      return;
    }

    final item = _cartItems[itemIndex];
    if (!item.canAdjustQuantity) {
      debugPrint(
        '⚠️ Quantity locked for ${item.name} (served_by: ${item.servedBy})',
      );
      return;
    }
    final currentQty = item.quantity > 0 ? item.quantity : 1;
    final targetQty = currentQty + delta;
    if (targetQty < 0) return;
    if (targetQty == currentQty) return;

    if (targetQty < 1) {
      await removeFromCart(itemId, rowIndex: rowIndex);
      return;
    }

    final loaderKey = rowIndex != null ? '${itemId}_$rowIndex' : itemId;

    final auth = await _resolveCartAuth();
    if (auth.token == null) {
      debugPrint('⚠️ No token — cannot update quantity on server');
      return;
    }

    debugPrint(
      'check-auth qty step: ${item.name} $currentQty → $targetQty '
      '(delta $delta)',
    );

    _inhibitRemoteCartSync = true;
    _holdRemoteCartSync(const Duration(seconds: 5));
    try {
      await _withLoader(
        loaderKey,
        () async {
          final synced = await _setQuantityViaCheckAuth(
            item,
            targetQty,
            auth.token!,
            auth.isLoggedIn,
            previousQuantity: currentQty,
          );
          if (!synced) {
            throw Exception('check-auth quantity update failed');
          }
        },
      );
    } catch (e) {
      debugPrint('⚠️ Update error for ${item.name}: $e');
      if (e is TimeoutException) {
        _showSyncError('Update timed out. Please try again.');
      } else if (e is! StateError) {
        _showSyncError('Quantity update failed. Please try again.');
      }
    } finally {
      _inhibitRemoteCartSync = false;
    }
  }

  int _resolveCartLineIndex(String itemId, {int? rowIndex}) {
    if (rowIndex != null && rowIndex >= 0 && rowIndex < _cartItems.length) {
      return rowIndex;
    }
    if (itemId.isNotEmpty) {
      final byId = _cartItems.indexWhere((item) => item.id == itemId);
      if (byId != -1) return byId;
    }
    return -1;
  }

  /// Legacy entry — prefer [incrementCartLine] / [decrementCartLine].
  Future<void> updateQuantityById(String itemId, int newQuantity,
      {int? rowIndex}) async {
    final itemIndex = _resolveCartLineIndex(itemId, rowIndex: rowIndex);
    if (itemIndex == -1) return;
    final currentQty = _cartItems[itemIndex].quantity;
    if (newQuantity > currentQty) {
      await incrementCartLine(itemId, rowIndex: rowIndex);
    } else if (newQuantity < currentQty) {
      await decrementCartLine(itemId, rowIndex: rowIndex);
    }
  }

  Future<void> updateQuantity(int index, int newQuantity) async {
    if (index < 0 || index >= _cartItems.length) return;
    await updateQuantityById(
      _cartItems[index].id,
      newQuantity,
      rowIndex: index,
    );
  }

  /// Catalog `productID` first — check-auth rejects server `product_id` (404).
  List<int> _productIdCandidatesForCheckAuth(CartItem item) {
    final ids = <int>[];
    void add(int? value) {
      if (value != null && value > 0 && !ids.contains(value)) {
        ids.add(value);
      }
    }

    add(int.tryParse(item.originalProductId ?? ''));
    add(int.tryParse(item.productId));
    add(item.serverProductId);
    return ids;
  }

  Map<String, String> _cartAuthHeaders(String token, bool isLoggedIn) =>
      CartService.cartAuthHeaders(token, isLoggedIn);

  Future<({String? token, bool isLoggedIn})> _resolveCartAuth() async {
    var isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      var guestId = prefs.getString('guest_id');
      if (guestId == null || guestId.isEmpty) {
        try {
          guestId = await AuthService.generateGuestId();
        } catch (e) {
          debugPrint('[CartProvider] guest_id unavailable: $e');
        }
      }
    }

    isLoggedIn = await AuthService.isLoggedIn();
    var token = await AuthService.getToken();
    if (!isLoggedIn && (token == null || token.isEmpty)) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('guest_id');
    }
    return (token: token, isLoggedIn: isLoggedIn);
  }

  /// POST /check-auth with the **absolute** line quantity (not a delta).
  Future<bool> _setQuantityViaCheckAuth(
    CartItem item,
    int targetQuantity,
    String token,
    bool isLoggedIn, {
    required int previousQuantity,
  }) async {
    if (targetQuantity < 1) return false;

    final candidates = _productIdCandidatesForCheckAuth(item);
    if (candidates.isEmpty) return false;

    final headers = _cartAuthHeaders(token, isLoggedIn);
    final response = await _cartService.checkAuthWithProductCandidates(
      headers: headers,
      productIds: candidates,
      quantity: targetQuantity,
      batchNo: item.batchNo.isNotEmpty ? item.batchNo : null,
      timeout: _cartHttpTimeout,
      onAttempt: ({
        required String url,
        required Map<String, String> headers,
        required String requestBody,
        required CategoryFetchResult result,
      }) {
        _logCartApiResponse(
          label: 'UPDATE QUANTITY API RESPONSE (check-auth)',
          url: url,
          headers: headers,
          requestBody: requestBody,
          result: result,
        );
      },
    );

    if (!CartService.isSuccessStatus(response.statusCode)) {
      return false;
    }

    final data = CartService.decodeBody(response);
    return _applyCheckAuthCartResponse(
      data,
      productHint: item,
      wasDecrease: targetQuantity < previousQuantity,
    );
  }

  Future<bool> _removeCartLineById(
    String cartLineId,
    String token,
    bool isLoggedIn, {
    String? reason,
  }) async {
    final headers = _cartAuthHeaders(token, isLoggedIn);
    final requestBody = jsonEncode({'cart_id': cartLineId});

    final response = await _cartService.removeCartLine(
      headers: headers,
      cartLineId: cartLineId,
      timeout: _cartHttpTimeout,
    );

    _logCartApiResponse(
      label: reason != null
          ? 'REMOVE FROM CART API RESPONSE ($reason)'
          : 'REMOVE FROM CART API RESPONSE',
      url: 'remove-from-cart',
      headers: headers,
      requestBody: requestBody,
      result: response,
    );

    if (!CartService.isSuccessStatus(response.statusCode)) {
      return false;
    }
    try {
      final data = CartService.decodeBody(response);
      return data?['status']?.toString() == 'success';
    } catch (_) {
      return true;
    }
  }

  // Show user-friendly error message
  void _showSyncError(String message) {
    debugPrint('🔄 Sync Error: $message');
    // Note: In a real app, you might want to show a snackbar or notification
    // For now, we'll just log the error
  }

  void clearCart() async {
    await GuestCheckoutDraftService.clearAfterSuccessfulCheckout();
    _cartItems.clear();
    notifyListeners();

    debugPrint('🛒 CartProvider: Cart cleared successfully');
  }

  double calculateTotal() {
    return _chargeableLines.fold(0.0, (total, item) => total + CartItem.lineCharge(item));
  }

  double calculateSubtotal() {
    return _chargeableLines.fold(
      0.0,
      (subtotal, item) => subtotal + CartItem.lineCharge(item),
    );
  }

  /// Lines included in checkout totals. If nothing is marked selected (common when
  /// the API omits or zeroes `is_selected`), all lines count so the total matches the list.
  Iterable<CartItem> get _chargeableLines {
    final selected = _cartItems.where((item) => item.isSelected);
    if (selected.isNotEmpty) return selected;
    return _cartItems;
  }

  // Toggle selection for a cart item
  void toggleItemSelection(String itemId) {
    final index = _cartItems.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _cartItems[index] = _cartItems[index].copyWith(
        isSelected: !_cartItems[index].isSelected,
      );
      notifyListeners();
      debugPrint(
          '🛒 CartProvider: Toggled selection for item ${_cartItems[index].name}: ${_cartItems[index].isSelected}');
    }
  }

  // Get only selected items
  List<CartItem> getSelectedItems() {
    final selected = _cartItems.where((item) => item.isSelected).toList();
    if (selected.isNotEmpty) return selected;
    return List<CartItem>.from(_cartItems);
  }

  /// Re-asserts each selected line on the API cart via [/check-auth].
  Future<void> reaffirmSelectedItemsOnServer() async {
    if (_remoteSyncPaused) return;
    final selected = getSelectedItems();
    if (selected.isEmpty) return;

    final auth = await _resolveCartAuth();
    final token = auth.token;
    if (token == null || token.isEmpty) return;

    debugPrint(
      '[CartProvider] Reaffirming ${selected.length} selected item(s) on server cart',
    );
    for (final item in selected) {
      await _setQuantityViaCheckAuth(
        item,
        item.quantity,
        token,
        auth.isLoggedIn,
        previousQuantity: item.quantity,
      );
    }
  }

  // Get count of selected items
  int get selectedItemsCount {
    return _cartItems
        .where((item) => item.isSelected)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _savePurchasedItems() async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'purchasedItems_$_currentUserId';
    final purchasedJson =
        jsonEncode(_purchasedItems.map((item) => item.toJson()).toList());
    await prefs.setString(key, purchasedJson);
  }

  Future<void> _loadPurchasedItems() async {
    if (_currentUserId == null) {
      _purchasedItems = [];
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = 'purchasedItems_$_currentUserId';
    final purchasedJson = prefs.getString(key);

    if (purchasedJson != null) {
      final purchasedList = jsonDecode(purchasedJson) as List;
      _purchasedItems = purchasedList
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      _purchasedItems = [];
    }
  }

  Future<void> handleUserLogin(String userId) async {
    _currentUserId = userId;
    _cartItems = [];

    await _loadPurchasedItems();
    notifyListeners();

    debugPrint(
        '🛒 CartProvider: User logged in — loading cart from server: $userId');
    await syncWithApi();
    _scheduleBackgroundCartSync();
  }

  Future<void> handleUserLogout() async {
    _currentUserId = null;
    _cartItems = [];
    _purchasedItems = [];
    notifyListeners();

    debugPrint('🛒 CartProvider: User logged out — cart cleared');
    await syncWithApi();
  }

  Future<void> refreshLoginStatus() async {
    await _checkCurrentUser();
    _scheduleBackgroundCartSync();
  }

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  /// Use with [Selector] so only badge widgets rebuild when count changes.
  static int selectTotalItems(CartProvider cart) => cart.totalItems;

  /// Use with [Selector] on product detail — rebuilds only when this SKU qty changes.
  static int selectQuantityForProduct(
    CartProvider cart, {
    required String productName,
    required String batchNo,
    String? catalogProductId,
  }) {
    return findLineForSku(
          cart,
          productName: productName,
          batchNo: batchNo,
          catalogProductId: catalogProductId,
        )?.quantity ??
        0;
  }

  static bool selectIsProductInCart(
    CartProvider cart, {
    required String productName,
    required String batchNo,
    String? catalogProductId,
  }) =>
      selectQuantityForProduct(
        cart,
        productName: productName,
        batchNo: batchNo,
        catalogProductId: catalogProductId,
      ) >
      0;

  /// Use with [Selector] on checkout summary rows.
  static double selectSubtotal(CartProvider cart) => cart.calculateSubtotal();

  int get displayTotalItems {
    // Only show cart count if user is logged in
    if (_currentUserId == null) return 0;
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  void setCartItems(List<CartItem> items) {
    // Merge items with the same product_id AND batchNo by summing their quantities
    final Map<String, CartItem> merged = {};
    for (final item in items) {
      final String uniqueKey = '${item.urlName}_${item.batchNo}';
      if (merged.containsKey(uniqueKey)) {
        merged[uniqueKey] = merged[uniqueKey]!.copyWith(
          quantity: merged[uniqueKey]!.quantity + item.quantity,
        );
      } else {
        merged[uniqueKey] = item;
      }
    }
    _cartItems = merged.values.toList();
    notifyListeners();
  }

  // Merge in-session guest cart into the logged-in user's server cart.
  Future<void> mergeGuestCartOnLogin(String userId) async {
    debugPrint('🔄 Starting cart merge for user: $userId');

    final guestCart = List<CartItem>.from(_cartItems);
    _currentUserId = userId;
    _cartItems = [];
    notifyListeners();

    await syncWithApi();

    final Map<String, CartItem> merged = {};
    for (final item in [..._cartItems, ...guestCart]) {
      final String uniqueKey = '${item.urlName}_${item.batchNo}';
      if (merged.containsKey(uniqueKey)) {
        merged[uniqueKey] = merged[uniqueKey]!.copyWith(
          quantity: merged[uniqueKey]!.quantity + item.quantity,
        );
      } else {
        merged[uniqueKey] = item;
      }
    }

    _cartItems = merged.values.toList();
    notifyListeners();

    debugPrint('✅ Cart merge completed. Items: ${_cartItems.length}');

    _syncMergedCartInBackground();
    _scheduleBackgroundCartSync();
  }

  // Fast background sync for merged cart
  Future<void> _syncMergedCartInBackground() async {
    try {
      debugPrint('🔄 Starting background server sync...');

      // Use batch operations instead of individual calls
      await _batchSyncCartToServer();

      debugPrint('✅ Background server sync completed');
      _scheduleBackgroundCartSync();
    } catch (e) {
      debugPrint('⚠️ Background sync failed: $e');
      // Don't show error to user - cart is already merged locally
    }
  }

  // Batch sync cart to server - much faster than individual calls
  Future<void> _batchSyncCartToServer() async {
    if (_currentUserId == null || _cartItems.isEmpty) return;

    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      // Clear existing server cart first
      await _clearServerCart(token);

      // Add all items in batch
      final futures = _cartItems
          .map((item) => _syncAddToServer(item, quantity: item.quantity))
          .toList();
      await Future.wait(futures);

      debugPrint('✅ Batch sync completed for ${_cartItems.length} items');
    } catch (e) {
      debugPrint('⚠️ Batch sync error: $e');
      rethrow;
    }
  }

  // Clear server cart before adding merged items
  Future<void> _clearServerCart(String token) async {
    try {
      final hashedLink = await AuthService.getHashedLink() ?? '';
      final response = await _cartService.fetchLoggedInCart(
        hashedLink: hashedLink,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        timeout: const Duration(seconds: 3),
      );

      if (response.statusCode == 200) {
        final data = CartService.decodeBody(response);
        if (data?['cart_items'] != null) {
          final serverItems = data!['cart_items'] as List;
          for (final item in serverItems) {
            final itemId = item['id']?.toString();
            if (itemId != null) {
              await _removeFromServer(itemId, token);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Clear server cart error: $e');
    }
  }

  // Remove item from server
  Future<void> _removeFromServer(String itemId, String token) async {
    try {
      await _cartService.deleteCheckoutItem(
        itemId: itemId,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        timeout: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('⚠️ Remove from server error: $e');
    }
  }

  Future<void> testBackgroundCheck() async {
    debugPrint('🛒 CartProvider: Testing background cart check...');
    try {
      await RealtimeCartSyncService().forceImmediateSync();
      debugPrint('🛒 CartProvider: Background cart check completed');
    } catch (e) {
      debugPrint('🛒 CartProvider: Error testing background cart check: $e');
    }
  }

  /// Clean up duplicate items in cart
  Future<void> cleanupDuplicateItems() async {
    debugPrint('🧹 CartProvider: Cleaning up duplicate items...');

    final Map<String, CartItem> uniqueItems = {};
    final List<CartItem> cleanedItems = [];

    for (final item in _cartItems) {
      final key = '${item.name.toLowerCase()}_${item.batchNo}';

      if (uniqueItems.containsKey(key)) {
        // Merge quantities
        final existingItem = uniqueItems[key]!;
        final mergedQuantity = existingItem.quantity + item.quantity;
        uniqueItems[key] = existingItem.copyWith(quantity: mergedQuantity);
        debugPrint(
            '🔗 Merged duplicate: ${item.name} (${item.quantity} + ${existingItem.quantity} = $mergedQuantity)');
      } else {
        uniqueItems[key] = item;
        cleanedItems.add(item);
      }
    }

    if (cleanedItems.length != _cartItems.length) {
      _cartItems = uniqueItems.values.toList();
      notifyListeners();
      debugPrint(
          '✅ Cleaned up ${_cartItems.length - cleanedItems.length} duplicate items');
    } else {
      debugPrint('✅ No duplicate items found');
    }
  }

  /// Clean up server-side duplicates and sync
  Future<void> cleanupServerDuplicates() async {
    debugPrint('🧹 CartProvider: Cleaning up server-side duplicates...');

    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      // Get current cart from server
      final hashedLink = await AuthService.getHashedLink() ?? '';
      final cartResponse = await _cartService.fetchLoggedInCart(
        hashedLink: hashedLink,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (cartResponse.statusCode == 200) {
        final cartData = CartService.decodeBody(cartResponse);
        final cartItems = cartData?['cart_items'] as List? ?? [];

        // Group items by product name and batch
        final Map<String, List<Map<String, dynamic>>> groupedItems = {};

        for (final item in cartItems) {
          final productName = item['product_name']?.toString() ?? '';
          final batchNo = item['batch_no']?.toString() ?? '';
          final key = '${productName.toLowerCase()}_$batchNo';

          if (!groupedItems.containsKey(key)) {
            groupedItems[key] = [];
          }
          groupedItems[key]!.add(item);
        }

        // Remove duplicates, keeping only the first item of each group
        for (final entry in groupedItems.entries) {
          final items = entry.value;
          if (items.length > 1) {
            debugPrint('Found ${items.length} duplicates for ${entry.key}');

            // Keep the first item, remove the rest
            for (int i = 1; i < items.length; i++) {
              final itemId = items[i]['id']?.toString();
              if (itemId != null) {
                await _cartService.removeCartLine(
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  },
                  cartLineId: itemId,
                );
                debugPrint('Removed duplicate item ID: $itemId');
              }
            }
          }
        }

        // Sync with server to get updated cart state
        await syncWithApi();
        debugPrint('✅ Server-side duplicates cleaned up');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up server duplicates: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
