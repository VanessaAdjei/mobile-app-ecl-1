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

  // Map to store carts for different users
  Map<String, List<CartItem>> _userCarts = {};
  // Current user's cart items
  List<CartItem> _cartItems = [];
  List<CartItem> _purchasedItems = [];
  String? _currentUserId;
  // Flag to prevent loading guest cart after logout - cart should stay empty until login
  bool _shouldLoadGuestCart = true;
  bool _isDisposed = false;
  /// Blocks background/full cart fetch while a delete is in flight (avoids re-adding rows).
  bool _inhibitRemoteCartSync = false;

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

  bool _productNamesLooselyMatch(String a, String b) {
    final na = _normalizeProductName(a);
    final nb = _normalizeProductName(b);
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    final wordsA =
        na.split(' ').where((w) => w.length > 2).toSet();
    final wordsB =
        nb.split(' ').where((w) => w.length > 2).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return false;
    final common = wordsA.intersection(wordsB).length;
    return common >= 2 ||
        (common >= 1 && wordsA.first == wordsB.first);
  }

  bool _sameCartProduct(CartItem a, CartItem b) {
    if (a.batchNo.isNotEmpty &&
        b.batchNo.isNotEmpty &&
        a.batchNo != b.batchNo) {
      return false;
    }
    if (_productNamesLooselyMatch(a.name, b.name)) {
      return true;
    }
    final aOrig = a.originalProductId ?? a.productId;
    final bOrig = b.originalProductId ?? b.productId;
    if (aOrig.isNotEmpty && aOrig == bOrig && a.batchNo == b.batchNo) {
      return true;
    }
    return false;
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
          serverProductId:
              primary.serverProductId ?? secondary.serverProductId,
          originalProductId:
              primary.originalProductId ?? secondary.originalProductId,
        );
      }
    }
    if (merged.length != _cartItems.length) {
      _cartItems = merged.values.toList();
      unawaited(_saveUserCarts());
      notifyListeners();
    }
  }

  int _findLocalCartIndex({
    required String name,
    required String batchNo,
  }) {
    final byName = _cartItems.indexWhere((c) {
      if (batchNo.isNotEmpty && c.batchNo != batchNo) return false;
      return _normalizeProductName(c.name) == _normalizeProductName(name);
    });
    if (byName != -1) return byName;

    if (batchNo.isEmpty) return -1;
    final byBatch = _cartItems.where((c) => c.batchNo == batchNo).toList();
    if (byBatch.length == 1) {
      return _cartItems.indexOf(byBatch.first);
    }
    return _cartItems.indexWhere(
      (c) => c.batchNo == batchNo && _productNamesLooselyMatch(c.name, name),
    );
  }

  bool _serverLineMatchesProduct(Map<String, dynamic> line, CartItem item) {
    final name = line['product_name']?.toString() ?? '';
    final batch = line['batch_no']?.toString() ?? '';
    return _productNamesLooselyMatch(name, item.name) &&
        (item.batchNo.isEmpty || batch == item.batchNo);
  }

  List<Map<String, dynamic>> _matchingServerCartLines(
    List<dynamic> serverItems,
    CartItem item,
  ) {
    return serverItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((m) => _serverLineMatchesProduct(m, item))
        .toList();
  }

  /// Applies the qty the user chose; only refreshes line ids/prices from the server.
  void _applyLocalQuantityTarget(
    CartItem item,
    int targetQuantity,
    List<dynamic> serverItems, {
    String? catalogProductId,
  }) {
    final localIndex =
        _findLocalCartIndex(name: item.name, batchNo: item.batchNo);
    if (localIndex == -1) return;

    final lines = _matchingServerCartLines(serverItems, item);
    if (lines.isNotEmpty) {
      final primary = CartItem.fromServerJson(lines.first);
      _cartItems[localIndex] = _cartItems[localIndex].copyWith(
        id: primary.id.isNotEmpty ? primary.id : _cartItems[localIndex].id,
        serverProductId:
            primary.serverProductId ?? _cartItems[localIndex].serverProductId,
        originalProductId: catalogProductId ??
            _cartItems[localIndex].originalProductId,
        price: primary.price,
        totalPrice: primary.price * targetQuantity,
      );
    }

    _cartItems[localIndex].updateQuantity(targetQuantity);
    debugPrint(
      '✅ Local qty kept at $targetQuantity for ${item.name} (server had ${lines.length} line(s))',
    );
    unawaited(_saveUserCarts());
    notifyListeners();
  }

  /// Sets local qty/price/ids from matching rows in check-auth `items` (source of truth).
  void _reconcileLocalQuantityFromServerResponse(
    List<dynamic> serverItems,
    CartItem item, {
    String? catalogProductId,
  }) {
    final lines = _matchingServerCartLines(serverItems, item);
    if (lines.isEmpty) return;

    var totalQty = 0;
    var totalPrice = 0.0;
    double unitPrice = item.price;
    String? primaryLineId;
    int? serverProductId;

    for (final line in lines) {
      final parsed = CartItem.fromServerJson(line);
      totalQty += parsed.quantity;
      totalPrice += parsed.totalPrice;
      unitPrice = parsed.price;
      primaryLineId ??= parsed.id;
      serverProductId ??= parsed.serverProductId;
    }

    final localIndex =
        _findLocalCartIndex(name: item.name, batchNo: item.batchNo);
    if (localIndex == -1) return;

    _cartItems[localIndex] = _cartItems[localIndex].copyWith(
      quantity: totalQty,
      totalPrice: totalPrice > 0 ? totalPrice : unitPrice * totalQty,
      price: unitPrice,
      id: primaryLineId ?? _cartItems[localIndex].id,
      serverProductId: serverProductId ?? _cartItems[localIndex].serverProductId,
      originalProductId:
          catalogProductId ?? _cartItems[localIndex].originalProductId,
    );

    debugPrint(
      '✅ Reconciled local qty for ${item.name}: $totalQty (${lines.length} server line(s))',
    );
    unawaited(_saveUserCarts());
    notifyListeners();
  }

  /// Links server line ids to local rows from check-auth response (no full cart fetch).
  bool _applyServerCartLinesFromResponse(
    List<dynamic> serverItems, {
    String? pendingOriginalProductId,
    String? pendingName,
    String? pendingBatch,
  }) {
    var applied = false;
    for (final raw in serverItems) {
      if (raw is! Map) continue;
      final serverName = raw['product_name']?.toString() ?? '';
      final serverBatch = raw['batch_no']?.toString() ?? '';
      final serverCartId = raw['id']?.toString();
      final serverProductId =
          int.tryParse(raw['product_id']?.toString() ?? '');
      if (serverCartId == null) continue;

      var localIndex =
          _findLocalCartIndex(name: serverName, batchNo: serverBatch);
      if (localIndex == -1 &&
          pendingBatch != null &&
          pendingBatch == serverBatch) {
        localIndex = _findLocalCartIndex(
          name: pendingName ?? serverName,
          batchNo: pendingBatch,
        );
        if (localIndex == -1) {
          localIndex = _cartItems.indexWhere(
            (c) =>
                c.batchNo == pendingBatch &&
                _productNamesLooselyMatch(
                  c.name,
                  pendingName ?? serverName,
                ),
          );
        }
      }
      if (localIndex == -1) continue;

      _cartItems[localIndex] = _cartItems[localIndex].copyWith(
        id: serverCartId,
        serverProductId:
            serverProductId ?? _cartItems[localIndex].serverProductId,
        originalProductId: pendingOriginalProductId ??
            _cartItems[localIndex].originalProductId ??
            _cartItems[localIndex].productId,
      );
      applied = true;
    }
    if (applied) {
      unawaited(_saveUserCarts());
      notifyListeners();
    }
    return applied;
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
    await _loadUserCarts();
    await _checkCurrentUser();
  }

  Future<void> _initializeRealtimeSync() async {
    try {
      // Initialize real-time cart sync service with this CartProvider instance
      await RealtimeCartSyncService().initialize(this);
      debugPrint('🔄 CartProvider: Real-time cart sync service initialized');
    } catch (e) {
      debugPrint(
          '🔄 CartProvider: Error initializing real-time cart sync service: $e');
    }
  }

  Future<void> _checkCurrentUser() async {
    bool isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      String userId = (await AuthService.getCurrentUserID()) as String;
      _currentUserId = userId;
      _loadCurrentUserCart();
    } else {
      _currentUserId = null;
      _loadCurrentUserCart(); // Load guest cart when not logged in
    }
    notifyListeners();
  }

  Future<void> _loadUserCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('user_carts');
      if (cartJson != null) {
        final Map<String, dynamic> userCartsMap = jsonDecode(cartJson);
        _userCarts = {};

        userCartsMap.forEach((userId, cartData) {
          final cartList = (cartData as List).cast<Map<String, dynamic>>();
          _userCarts[userId] =
              cartList.map((item) => CartItem.fromJson(item)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading user carts: $e');
    }
  }

  void _loadCurrentUserCart() {
    if (_currentUserId != null && _userCarts.containsKey(_currentUserId)) {
      _cartItems = _userCarts[_currentUserId]!;
    } else if (_currentUserId == null &&
        _shouldLoadGuestCart &&
        _userCarts.containsKey('guest_id')) {
      // Load guest cart for non-logged-in users (only if allowed)
      _cartItems = _userCarts['guest_id']!;
    } else {
      _cartItems = [];
    }

    // Ensure all items are selected by default (for backward compatibility)
    _cartItems = _cartItems.map((item) {
      if (!item.isSelected) {
        return item.copyWith(isSelected: true);
      }
      return item;
    }).toList();

    _loadPurchasedItems();
  }

  Future<void> _saveUserCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_currentUserId != null) {
        _userCarts[_currentUserId!] = _cartItems;
      } else {
        _userCarts['guest_id'] = _cartItems;
      }

      // Convert user carts to JSON
      final Map<String, dynamic> userCartsJson = {};
      _userCarts.forEach((userId, cartItems) {
        userCartsJson[userId] = cartItems.map((item) => item.toJson()).toList();
      });

      await prefs.setString('user_carts', jsonEncode(userCartsJson));
    } catch (e) {
      debugPrint('Error saving user carts: $e');
    }
  }

  Future<void> syncWithApi() async {
    if (_inhibitRemoteCartSync) {
      debugPrint('⏸️ Cart sync skipped (delete in progress)');
      return;
    }
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot sync cart - missing auth token');
        return;
      }

      // Get the hashed link
      final hashedLink = await AuthService.getHashedLink();
      if (hashedLink == null) {
        debugPrint('Cannot sync cart - missing hashed link');
        return;
      }

      final response = await _cartService.fetchLoggedInCart(
        hashedLink: hashedLink,
        headers: {
          'Authorization': 'Bearer $token',
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

          if (rawItems.isEmpty && _cartItems.isNotEmpty) {
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
          await _saveUserCarts();
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
    debugPrint('🚀 ADD TO CART METHOD CALLED ===');
    debugPrint('Cart items count before adding: ${_cartItems.length}');
    debugPrint('Adding item: ${item.name}');
    debugPrint('================================');

    _currentUserId ??= await AuthService.getCurrentUserID();

    // --- GUEST SESSION LOGIC ---
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      // Re-enable guest cart loading when guest adds to cart
      _shouldLoadGuestCart = true;

      // Check if guest_id exists
      final prefs = await SharedPreferences.getInstance();
      String? guestId = prefs.getString('guest_id');
      if (guestId == null || guestId.isEmpty) {
        // Create guest_id (fetch from backend)
        guestId = await AuthService.generateGuestId();
        debugPrint('[CartProvider] Created guest_id: $guestId');
      }
    }
    // --- END GUEST SESSION LOGIC ---

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        // Fallback to local cart if no token
        debugPrint(
            'Cannot add to cart - missing auth token, adding to local cart');
        await _addToLocalCart(item);
        return;
      }

      final existingIndex =
          _cartItems.indexWhere((cartItem) => _sameCartProduct(cartItem, item));

      if (existingIndex != -1) {
        // Item exists, add to existing quantity
        final oldQuantity = _cartItems[existingIndex].quantity;
        final newQuantity = oldQuantity + item.quantity;

        debugPrint('🔍 ITEM EXISTS - ADDING TO QUANTITY ===');
        debugPrint('Product: ${item.name}');
        debugPrint('Old Quantity: $oldQuantity');
        debugPrint('Adding Quantity: ${item.quantity}');
        debugPrint('New Total Quantity: $newQuantity');
        debugPrint('=====================================');

        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
          originalProductId:
              item.originalProductId ?? item.productId,
          productId: item.productId.isNotEmpty
              ? item.productId
              : _cartItems[existingIndex].productId,
          batchNo: item.batchNo.isNotEmpty
              ? item.batchNo
              : _cartItems[existingIndex].batchNo,
        );
        _cartItems[existingIndex].updateQuantity(newQuantity);

        debugPrint('✅ ITEM UPDATED LOCALLY - WILL SYNC WITH SERVER ===');
        debugPrint('Product: ${item.name}');
        debugPrint('New Total Quantity: $newQuantity');
        debugPrint('Catalog Product ID: ${_cartItems[existingIndex].originalProductId}');
        debugPrint('App Product ID: ${_cartItems[existingIndex].productId}');
        debugPrint('Server Product ID: ${_cartItems[existingIndex].serverProductId}');
        debugPrint('Batch: ${_cartItems[existingIndex].batchNo}');
        debugPrint('========================================');

        await _saveUserCarts();
        notifyListeners();

        final synced = await _syncAddToServer(
          _cartItems[existingIndex],
          syncQuantity: item.quantity,
        );
        if (!synced) {
          _cartItems[existingIndex].updateQuantity(oldQuantity);
          await _saveUserCarts();
          notifyListeners();
          _showSyncError(
            'Could not add to cart on server. The product may be unavailable.',
          );
        }
      } else {
        _cartItems.add(item);

        debugPrint('✅ NEW ITEM ADDED LOCALLY - WILL SYNC WITH SERVER ===');
        debugPrint('Product: ${item.name}');
        debugPrint('Quantity: ${item.quantity}');
        debugPrint('Catalog Product ID: ${item.originalProductId}');
        debugPrint('App Product ID: ${item.productId}');
        debugPrint('============================================');

        await _saveUserCarts();
        notifyListeners();

        final synced = await _syncAddToServer(item);
        if (!synced) {
          _cartItems.removeWhere((c) => _sameCartProduct(c, item));
          await _saveUserCarts();
          notifyListeners();
          _showSyncError(
            'Could not add to cart on server. The product may be unavailable.',
          );
        }
      }
    } catch (e) {
      // Any exception, fallback to local cart
      debugPrint('Error adding to cart: $e, adding to local cart');
      await _addToLocalCart(item);
    }
  }

  /// Returns true when the server accepted the add/update.
  Future<bool> _syncAddToServer(CartItem item, {int? syncQuantity}) async {
    try {
      String? token = await AuthService.getToken();
      Map<String, String> headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      bool isLoggedIn = await AuthService.isLoggedIn();
      if (token != null) {
        if (isLoggedIn) {
          headers['Authorization'] = 'Bearer $token';
          debugPrint('[CartProvider] Using Bearer token for cart sync');
        } else if (token.startsWith('guest')) {
          headers['Authorization'] = 'Guest $token';
          headers['X-Guest-ID'] = token;
          debugPrint('[CartProvider] Using Guest token for cart sync');
        } else {
          debugPrint('Token present but not logged in and not a guest_id.');
          return false;
        }
      } else {
        debugPrint(
            'Cannot sync add to server - missing auth token and guest_id');
        return false;
      }

      final candidates = _productIdCandidatesForCheckAuth(item);
      if (candidates.isEmpty) {
        debugPrint('❌ No valid product ID found - cannot add to cart');
        return false;
      }

      final qtyToSend = syncQuantity ?? item.quantity;
      final catalogProductId =
          item.originalProductId ?? item.productId;

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
        debugPrint(
            'Failed to add/update cart item on server: ${response.statusCode}');
        if (response.statusCode == 404) {
          debugPrint('⚠️ Product not found (404) after trying ids: $candidates');
          debugPrint('Product: ${item.name}');
          debugPrint('Batch: ${item.batchNo}');
          debugPrint('Response: ${response.rawBody}');
        }
        return false;
      }

      debugPrint('Successfully added item to server cart');

      List<dynamic> serverItems = [];
      var serverLineIdApplied = false;
      try {
        final responseData = CartService.decodeBody(response);
        if (responseData != null) {
          serverItems = responseData['items'] as List? ?? [];
        }
        if (syncQuantity != null) {
          final idx =
              _findLocalCartIndex(name: item.name, batchNo: item.batchNo);
          final targetQty =
              idx >= 0 ? _cartItems[idx].quantity : item.quantity;
          _applyLocalQuantityTarget(
            item,
            targetQty,
            serverItems,
            catalogProductId: catalogProductId,
          );
        } else {
          _reconcileLocalQuantityFromServerResponse(
            serverItems,
            item,
            catalogProductId: catalogProductId,
          );
        }
        serverLineIdApplied = _applyServerCartLinesFromResponse(
          serverItems,
          pendingOriginalProductId: catalogProductId,
          pendingName: item.name,
          pendingBatch: item.batchNo,
        );
      } catch (e) {
        debugPrint('⚠️ Error extracting server cart ID from response: $e');
      }

      if (serverLineIdApplied) {
        _consolidateDuplicateCartLines();
        return true;
      }

      final syncedItemIndex = _findLocalCartIndex(
        name: item.name,
        batchNo: item.batchNo,
      );
      if (syncedItemIndex != -1) {
        _cartItems[syncedItemIndex] = _cartItems[syncedItemIndex].copyWith(
          originalProductId: catalogProductId,
        );
        notifyListeners();
        await _saveUserCarts();
        _consolidateDuplicateCartLines();
        return true;
      }

      _pendingOriginalProductId = catalogProductId;
      _pendingItemName = item.name;
      _pendingItemBatch = item.batchNo;
      await syncWithApi();
      _consolidateDuplicateCartLines();
      return true;
    } catch (e) {
      debugPrint('Error adding/updating cart item on server: $e');
      return false;
    }
  }

  // Helper method to add item to local cart with proper quantity handling
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

    await _saveUserCarts();
    notifyListeners();
  }

  void purchaseItems() async {
    if (_currentUserId == null) return;

    // Only add selected items to purchased items
    final selectedItems = _cartItems.where((item) => item.isSelected).toList();
    _purchasedItems.addAll(selectedItems);

    // Remove selected items from cart (keep unselected items)
    _cartItems.removeWhere((item) => item.isSelected);

    await _saveUserCarts();
    await _savePurchasedItems();
    notifyListeners();
  }

  /// Removes every cart line for this product locally and on the server.
  /// Pass [rowIndex] when the line has no server id yet (empty `cartId`).
  Future<void> removeFromCart(String cartId, {int? rowIndex}) async {
    CartItem? itemToRemove;
    if (rowIndex != null &&
        rowIndex >= 0 &&
        rowIndex < _cartItems.length &&
        (cartId.isEmpty || _cartItems[rowIndex].id == cartId)) {
      itemToRemove = _cartItems[rowIndex];
    } else {
      final itemIndex = _cartItems.indexWhere((item) => item.id == cartId);
      if (itemIndex != -1) {
        itemToRemove = _cartItems[itemIndex];
      }
    }

    if (itemToRemove == null) {
      debugPrint('❌ Item not found in cart with ID: $cartId');
      return;
    }
    final target = itemToRemove;

    debugPrint('=== REMOVE FROM CART (all instances) ===');
    debugPrint('Product: ${target.name}');
    debugPrint('Batch: ${target.batchNo}');
    debugPrint('Cart line ID: ${target.id}');
    debugPrint('========================================');

    // Remove every local row for this product (name/batch/ID match).
    _cartItems.removeWhere((item) => _sameCartProduct(item, target));
    await _saveUserCarts();
    notifyListeners();

    final isLoggedIn = await AuthService.isLoggedIn();
    String? token = await AuthService.getToken();
    if (!isLoggedIn && token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('guest_id');
    }
    if (token == null) return;

    _inhibitRemoteCartSync = true;
    try {
      await _removeAllProductInstances(
        target,
        token,
        isLoggedIn,
        allServerLines: true,
      );
    } catch (e) {
      debugPrint('⚠️ Error removing all server instances: $e');
      await syncWithApi();
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

    // Set loading state
    _updatingItemIds.add(itemId);
    notifyListeners();

    try {
      // Execute operation with timeout
      final result = await operation().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Operation timed out');
        },
      );
      return result;
    } finally {
      // Always clear loader when operation completes (success or failure)
      _updatingItemIds.remove(itemId);
      notifyListeners();
      debugPrint('✅ Loader cleared for item $itemId');
    }
  }

  // New method that uses item ID instead of index.
  // Pass [rowIndex] so only that row shows the loader (avoids loader on other items when ids duplicate).
  Future<void> updateQuantityById(String itemId, int newQuantity,
      {int? rowIndex}) async {
    int itemIndex = -1;
    if (rowIndex != null &&
        rowIndex >= 0 &&
        rowIndex < _cartItems.length &&
        (itemId.isEmpty || _cartItems[rowIndex].id == itemId)) {
      itemIndex = rowIndex;
    } else if (itemId.isNotEmpty) {
      itemIndex = _cartItems.indexWhere((item) => item.id == itemId);
    }
    if (itemIndex == -1) {
      debugPrint('⚠️ Item not found with ID: $itemId');
      return;
    }

    final item = _cartItems[itemIndex];
    final oldQuantity = item.quantity;

    debugPrint('=== UPDATE QUANTITY (local) ===');
    debugPrint('Product: ${item.name}');
    debugPrint('Batch: ${item.batchNo}');
    debugPrint('Old Quantity: $oldQuantity');
    debugPrint('New Quantity: $newQuantity');
    debugPrint('Cart line ID: ${item.id}');
    debugPrint('================================');

    // Update local state immediately for UI responsiveness
    _cartItems[itemIndex].updateQuantity(newQuantity);
    await _saveUserCarts();
    notifyListeners();

    final loaderKey = rowIndex != null ? '${itemId}_$rowIndex' : itemId;

    final isLoggedIn = await AuthService.isLoggedIn();
    String? token = await AuthService.getToken();

    if (!isLoggedIn && token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('guest_id');
    }

    if (token != null) {
      try {
        await _withLoader(loaderKey, () async {
          await _simpleQuantityUpdate(
            item,
            newQuantity,
            previousQuantity: oldQuantity,
          );
        });
      } catch (e) {
        debugPrint('⚠️ Update error for ${item.name}: $e');
        // Show user-friendly error message
        if (e is TimeoutException) {
          _showSyncError('Update timed out. Please try again.');
        } else if (e is! StateError) {
          // Don't show error for "already in progress" state errors
          _showSyncError('Quantity update failed. Please try again.');
        }
      }
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

  /// IDs to try for check-auth — catalog id first, then cart row ids.
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

  int? _resolveCartProductId(CartItem item) {
    final candidates = _productIdCandidatesForCheckAuth(item);
    return candidates.isEmpty ? null : candidates.first;
  }

  Map<String, String> _cartAuthHeaders(String token, bool isLoggedIn) =>
      CartService.cartAuthHeaders(token, isLoggedIn);

  int _localLineCountForProduct(CartItem item) {
    return _cartItems.where((c) => _sameCartProduct(c, item)).length;
  }

  void _syncLocalLineIdFromCheckAuthResponse(CartItem item, List<dynamic> items) {
    _applyServerCartLinesFromResponse(
      items,
      pendingOriginalProductId: item.originalProductId ?? item.productId,
      pendingName: item.name,
      pendingBatch: item.batchNo,
    );
  }

  /// One POST to check-auth (backend returns "Cart Updated" for qty changes).
  Future<bool> _fastQuantityUpdateViaCheckAuth(
    CartItem item,
    int quantityToSend,
    String token,
    bool isLoggedIn, {
    required int targetLocalQuantity,
  }) async {
    final productId = _resolveCartProductId(item);
    if (productId == null) return false;

    final headers = _cartAuthHeaders(token, isLoggedIn);
    final body = <String, dynamic>{
      'productID': productId,
      'quantity': quantityToSend > 0 ? quantityToSend : 1,
    };
    if (item.batchNo.isNotEmpty) {
      body['batch_no'] = item.batchNo;
    }
    final requestBody = jsonEncode(body);

    final response = await _cartService.checkAuth(
      headers: headers,
      body: body,
      timeout: _cartHttpTimeout,
    );

    _logCartApiResponse(
      label: 'UPDATE QUANTITY API RESPONSE (check-auth)',
      url: 'check-auth',
      headers: headers,
      requestBody: requestBody,
      result: response,
    );

    if (!CartService.isSuccessStatus(response.statusCode)) {
      return false;
    }

    try {
      final data = CartService.decodeBody(response);
      if (data == null) return false;
      final items = data['items'] as List? ?? [];
      final catalogId = item.originalProductId ?? item.productId;

      _applyLocalQuantityTarget(
        item,
        targetLocalQuantity,
        items,
        catalogProductId: catalogId,
      );

      final added = data['added']?.toString().toLowerCase() ?? '';
      return data['status']?.toString() == 'success' ||
          added.contains('updated');
    } catch (_) {
      return false;
    }
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

  Future<void> _simpleQuantityUpdate(
    CartItem item,
    int newQuantity, {
    int? previousQuantity,
  }) async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      String? token = await AuthService.getToken();

      if (token == null && !isLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('guest_id');
      }

      if (token == null) {
        return;
      }

      if (newQuantity <= 0) {
        await _removeAllProductInstances(
          item,
          token,
          isLoggedIn,
          allServerLines: true,
        );
        return;
      }

      final isIncrease =
          previousQuantity != null && newQuantity > previousQuantity;

      // Increases: only check-auth / add — never remove existing server lines.
      if (isIncrease) {
        final delta = newQuantity - previousQuantity;
        debugPrint(
          '🔄 Quantity sync path: increase (check-auth, +$delta → $newQuantity)',
        );
        final fast = await _fastQuantityUpdateViaCheckAuth(
          item,
          delta,
          token,
          isLoggedIn,
          targetLocalQuantity: newQuantity,
        );
        if (fast) {
          debugPrint('✅ Quantity increase synced via check-auth');
          await _saveUserCarts();
          return;
        }

        debugPrint(
            '🔄 Quantity sync fallback: add $delta unit(s) via check-auth');
        final synced = await _syncAddToServer(item, syncQuantity: delta);
        if (synced) {
          final idx =
              _findLocalCartIndex(name: item.name, batchNo: item.batchNo);
          if (idx >= 0) {
            _cartItems[idx].updateQuantity(newQuantity);
          }
          await _saveUserCarts();
          notifyListeners();
        }
        return;
      }

      final localLines = _localLineCountForProduct(item);

      // Decrease / set: fast check-auth, then remove+re-add if needed.
      if (localLines <= 1) {
        debugPrint('🔄 Quantity sync path: fast (check-auth only)');
        final fast = await _fastQuantityUpdateViaCheckAuth(
          item,
          newQuantity,
          token,
          isLoggedIn,
          targetLocalQuantity: newQuantity,
        );
        if (fast) {
          debugPrint('✅ Quantity sync: fast path succeeded');
          await _saveUserCarts();
          return;
        }

        if (hasServerCartLineId(item.id)) {
          debugPrint(
              '🔄 Quantity sync path: remove line + re-add (check-auth)');
          await _removeCartLineById(
            item.id,
            token,
            isLoggedIn,
            reason: 'quantity decrease fallback',
          );
          await _addSingleItemWithQuantity(item, newQuantity, token);
          return;
        }
      }

      debugPrint(
          '🔄 Quantity sync path: slow (fetch cart, remove duplicates, re-add)');
      await _removeAllProductInstances(
        item,
        token,
        isLoggedIn,
        allServerLines: true,
      );
      await _addSingleItemWithQuantity(item, newQuantity, token);
    } catch (e) {
      debugPrint('❌ Quantity sync error: $e');
      _showSyncError('Quantity update failed. Please try again.');
    }
  }

  // Remove all instances of a product from cart (server).
  Future<void> _removeAllProductInstances(
    CartItem item,
    String token,
    bool isLoggedIn, {
    bool allServerLines = false,
  }) async {
    try {
      if (!allServerLines &&
          _localLineCountForProduct(item) <= 1 &&
          hasServerCartLineId(item.id)) {
        await _removeCartLineById(
          item.id,
          token,
          isLoggedIn,
          reason: 'single line cleanup',
        );
        return;
      }

      final headers = _cartAuthHeaders(token, isLoggedIn);
      final fetchHeaders = Map<String, String>.from(headers);
      fetchHeaders.remove('Content-Type');

      CategoryFetchResult cartResponse;
      String fetchUrl;
      String? fetchBody;

      if (isLoggedIn) {
        final hashedLink = await AuthService.getHashedLink();
        if (hashedLink == null) {
          debugPrint('Cannot remove instances - missing hashed link');
          return;
        }
        fetchUrl = 'checkout/$hashedLink';
        cartResponse = await _cartService.fetchLoggedInCart(
          hashedLink: hashedLink,
          headers: fetchHeaders,
        );
      } else {
        fetchUrl = 'check-auth';
        fetchBody = jsonEncode({'productID': 0, 'quantity': 0});
        cartResponse = await _cartService.fetchGuestCart(
          headers: {
            ...fetchHeaders,
            'Content-Type': 'application/json',
          },
        );
      }

      _logCartApiResponse(
        label: 'FETCH CART (before remove all) API RESPONSE',
        url: fetchUrl,
        headers: isLoggedIn
            ? fetchHeaders
            : {
                ...fetchHeaders,
                'Content-Type': 'application/json',
              },
        requestBody: fetchBody,
        result: cartResponse,
      );

      if (cartResponse.statusCode == 200) {
        final cartData = CartService.decodeBody(cartResponse);
        if (cartData == null) return;
        final cartItems = isLoggedIn
            ? (cartData['cart_items'] as List? ?? [])
            : (cartData['items'] as List? ?? []);

        final itemsToRemove = cartItems.where((serverItem) {
          final serverProductName =
              serverItem['product_name']?.toString() ?? '';
          final serverBatchNo = serverItem['batch_no']?.toString() ?? '';
          return _productNamesLooselyMatch(serverProductName, item.name) &&
              serverBatchNo == item.batchNo;
        }).toList();

        debugPrint(
            'Removing ${itemsToRemove.length} server line(s) for ${item.name}');

        final removeFutures = <Future<bool>>[];
        for (final serverItem in itemsToRemove) {
          final itemId = serverItem['id']?.toString();
          if (itemId != null) {
            removeFutures.add(
              _removeCartLineById(
                itemId,
                token,
                isLoggedIn,
                reason:
                    allServerLines ? 'delete all instances' : 'duplicate cleanup',
              ),
            );
          }
        }
        await Future.wait(removeFutures);
      }
    } catch (e) {
      debugPrint('⚠️ Error removing product instances: $e');
    }
  }

  // Add single item with correct quantity
  Future<void> _addSingleItemWithQuantity(
      CartItem item, int quantity, String token) async {
    try {
      final productId = _resolveCartProductId(item);
      if (productId == null) return;

      final isLoggedIn = await AuthService.isLoggedIn();
      final body = <String, dynamic>{
        'productID': productId,
        'quantity': quantity,
      };
      if (item.batchNo.isNotEmpty) {
        body['batch_no'] = item.batchNo;
      }

      final headers = _cartAuthHeaders(token, isLoggedIn);
      final requestBody = jsonEncode(body);

      final addResponse = await _cartService.checkAuth(
        headers: headers,
        body: body,
        timeout: _cartHttpTimeout,
      );

      _logCartApiResponse(
        label: 'UPDATE QUANTITY API RESPONSE (check-auth re-add)',
        url: 'check-auth',
        headers: headers,
        requestBody: requestBody,
        result: addResponse,
      );

      if (CartService.isSuccessStatus(addResponse.statusCode)) {
        try {
          final data = CartService.decodeBody(addResponse);
          _syncLocalLineIdFromCheckAuthResponse(
            item,
            data?['items'] as List? ?? [],
          );
          await _saveUserCarts();
        } catch (_) {}
      } else {
        _showSyncError('Failed to update quantity. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Error adding single item: $e');
      _showSyncError('Failed to update quantity. Please try again.');
    }
  }

  // Show user-friendly error message
  void _showSyncError(String message) {
    debugPrint('🔄 Sync Error: $message');
    // Note: In a real app, you might want to show a snackbar or notification
    // For now, we'll just log the error
  }

  void clearCart() async {
    // Clear cart regardless of login status
    await GuestCheckoutDraftService.clearAfterSuccessfulCheckout();
    _cartItems.clear();

    // Also clear from user carts map
    if (_currentUserId != null) {
      _userCarts[_currentUserId!] = [];
    } else {
      _userCarts['guest_id'] = [];
    }

    await _saveUserCarts();
    notifyListeners();

    debugPrint('🛒 CartProvider: Cart cleared successfully');
  }

  double calculateTotal() {
    return _cartItems.fold(
        0,
        (total, item) =>
            item.isSelected ? total + (item.price * item.quantity) : total);
  }

  double calculateSubtotal() {
    return _cartItems.fold(
        0,
        (subtotal, item) => item.isSelected
            ? subtotal + (item.price * item.quantity)
            : subtotal);
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
    return _cartItems.where((item) => item.isSelected).toList();
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
    // Re-enable guest cart loading after login (in case user logs out again)
    _shouldLoadGuestCart = true;

    // Load this user's cart if it exists
    if (_userCarts.containsKey(userId)) {
      _cartItems = _userCarts[userId]!;
    } else {
      _cartItems = [];
      _userCarts[userId] = _cartItems;
    }

    // Load purchased items for this user
    await _loadPurchasedItems();
    // Don't sync immediately on login - let the protection mechanism handle it
    // The local cart is the source of truth
    notifyListeners();

    debugPrint(
        '🛒 CartProvider: User logged in - cart loaded for user: $userId');
  }

  Future<void> handleUserLogout() async {
    // Save current cart before logout if user is logged in
    if (_currentUserId != null) {
      _userCarts[_currentUserId!] = _cartItems;
      await _saveUserCarts();
    }

    _currentUserId = null;
    _cartItems = [];
    _purchasedItems = [];
    // Prevent loading guest cart after logout - cart should stay empty until login
    _shouldLoadGuestCart = false;
    notifyListeners();

    debugPrint(
        '🛒 CartProvider: User logged out - cart cleared and guest cart loading disabled');
  }

  Future<void> refreshLoginStatus() async {
    await _checkCurrentUser();
  }

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  /// Use with [Selector] so only badge widgets rebuild when count changes.
  static int selectTotalItems(CartProvider cart) => cart.totalItems;

  /// Use with [Selector] on product detail — rebuilds only when this SKU qty changes.
  static int selectQuantityForProduct(
    CartProvider cart, {
    required String productName,
    required String batchNo,
  }) {
    final norm = normalizeProductName(productName);
    for (final item in cart.cartItems) {
      if (normalizeProductName(item.name) == norm && item.batchNo == batchNo) {
        return item.quantity;
      }
    }
    return 0;
  }

  static bool selectIsProductInCart(
    CartProvider cart, {
    required String productName,
    required String batchNo,
  }) =>
      selectQuantityForProduct(
            cart,
            productName: productName,
            batchNo: batchNo,
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

  // Merge guest cart into user cart after login - OPTIMIZED VERSION
  Future<void> mergeGuestCartOnLogin(String userId) async {
    debugPrint('🔄 Starting fast cart merge for user: $userId');

    final guestCart = _userCarts['guest_id'] ?? [];
    final userCart = _userCarts[userId] ?? [];

    // Merge logic: combine items, summing quantities for duplicates
    final Map<String, CartItem> merged = {};
    for (final item in [...userCart, ...guestCart]) {
      final String uniqueKey = '${item.urlName}_${item.batchNo}';
      if (merged.containsKey(uniqueKey)) {
        merged[uniqueKey] = merged[uniqueKey]!.copyWith(
          quantity: merged[uniqueKey]!.quantity + item.quantity,
        );
      } else {
        merged[uniqueKey] = item;
      }
    }

    // Update local cart immediately for instant UI feedback
    _userCarts[userId] = merged.values.toList();
    _cartItems = _userCarts[userId]!;
    _userCarts.remove('guest_id');

    // Save to local storage and notify UI immediately
    await _saveUserCarts();
    notifyListeners();

    debugPrint('✅ Local cart merge completed. Items: ${_cartItems.length}');

    // Sync with server in background (non-blocking)
    _syncMergedCartInBackground();
  }

  // Fast background sync for merged cart
  Future<void> _syncMergedCartInBackground() async {
    try {
      debugPrint('🔄 Starting background server sync...');

      // Use batch operations instead of individual calls
      await _batchSyncCartToServer();

      debugPrint('✅ Background server sync completed');
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
      final futures = _cartItems.map((item) => _syncAddToServer(item)).toList();
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
      await _saveUserCarts();
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
