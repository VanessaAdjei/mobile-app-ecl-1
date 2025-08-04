// pages/cartprovider.dart
import 'package:flutter/foundation.dart';
import 'cart_item.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import '../services/background_cart_checker.dart';

class CartProvider with ChangeNotifier {
  // Map to store carts for different users
  Map<String, List<CartItem>> _userCarts = {};
  // Current user's cart items
  List<CartItem> _cartItems = [];
  List<CartItem> _purchasedItems = [];
  String? _currentUserId;

  String? _pendingOriginalProductId;
  String? _pendingItemName;
  String? _pendingItemBatch;

  String _normalizeProductName(String name) {
    debugPrint('🔤 NORMALIZE PRODUCT NAME ===');
    debugPrint('Original: "$name"');

    final normalized = name.toLowerCase().trim();
    debugPrint('Normalized: "$normalized"');

    final words =
        normalized.split(' ').where((word) => word.isNotEmpty).toList();
    debugPrint('Words: $words');

    final result = words.join(' ').toLowerCase();
    debugPrint('Result: "$result"');
    debugPrint('=============================');

    return result;
  }

  List<CartItem> get cartItems => _cartItems;
  List<CartItem> get purchasedItems => _purchasedItems;
  String? get currentUserId => _currentUserId;

  CartProvider() {
    _initializeCart();
    _initializeBackgroundChecker();
  }

  Future<void> _initializeCart() async {
    await _loadUserCarts();
    await _checkCurrentUser();
  }

  Future<void> _initializeBackgroundChecker() async {
    try {
      // Initialize background cart checker with this CartProvider instance
      await BackgroundCartChecker().initialize(this);
      debugPrint('🛒 CartProvider: Background cart checker initialized');
    } catch (e) {
      debugPrint(
          '🛒 CartProvider: Error initializing background cart checker: $e');
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

      if (_cartItems.isEmpty) {
        _cartItems = [];
      }
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
    } else if (_currentUserId == null && _userCarts.containsKey('guest_id')) {
      // Load guest cart for non-logged-in users
      _cartItems = _userCarts['guest_id']!;
    } else {
      _cartItems = [];
    }

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

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-out/$hashedLink'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5)); // reduced timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

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

              debugPrint('🔗 MERGING DUPLICATE ITEMS ===');
              debugPrint('Product: ${cartItem.name}');
              debugPrint('Existing Quantity: ${existingItem.quantity}');
              debugPrint('New Item Quantity: ${cartItem.quantity}');
              debugPrint('Merged Quantity: $newQuantity');
              debugPrint('Merge Key: $mergeKey');
              debugPrint('================================');

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
                (localItem) {
                  final localNormalizedName =
                      _normalizeProductName(localItem.name);
                  final serverNormalizedName =
                      _normalizeProductName(cartItem.name);
                  return localNormalizedName == serverNormalizedName &&
                      localItem.batchNo == cartItem.batchNo;
                },
              );
            } catch (e) {
              // No matching local item found
              matchingLocalItem = null;
            }

            // If we found a matching local item, preserve its original product ID
            if (matchingLocalItem != null) {
              cartItem = cartItem.copyWith(
                originalProductId: matchingLocalItem.originalProductId ??
                    matchingLocalItem.productId,
              );
              debugPrint('🔍 PRESERVED ORIGINAL PRODUCT ID ===');
              debugPrint('Product: ${cartItem.name}');
              debugPrint('Original Product ID: ${cartItem.originalProductId}');
              debugPrint('Server Product ID: ${cartItem.productId}');
              debugPrint(
                  'Local Item Product ID: ${matchingLocalItem.productId}');
              debugPrint('====================================');
            } else {
              // Check if this is the pending item we're trying to preserve
              bool isPendingItem = (_pendingOriginalProductId != null &&
                  _pendingItemName != null &&
                  _pendingItemBatch != null &&
                  _normalizeProductName(cartItem.name) ==
                      _normalizeProductName(_pendingItemName!) &&
                  cartItem.batchNo == _pendingItemBatch!);

              if (isPendingItem) {
                cartItem = cartItem.copyWith(
                  originalProductId: _pendingOriginalProductId,
                );
                debugPrint(
                    '🔍 PRESERVED ORIGINAL PRODUCT ID (PENDING MATCH) ===');
                debugPrint('Product: ${cartItem.name}');
                debugPrint(
                    'Original Product ID: ${cartItem.originalProductId}');
                debugPrint('Server Product ID: ${cartItem.productId}');
                debugPrint(
                    'Pending Original Product ID: $_pendingOriginalProductId');
                debugPrint(
                    '==================================================');

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
                  debugPrint(
                      '🔍 PRESERVED ORIGINAL PRODUCT ID (FLEXIBLE MATCH) ===');
                  debugPrint('Product: ${cartItem.name}');
                  debugPrint(
                      'Original Product ID: ${cartItem.originalProductId}');
                  debugPrint('Server Product ID: ${cartItem.productId}');
                  debugPrint(
                      'Local Item Product ID: ${flexibleMatchingLocalItem.productId}');
                  debugPrint(
                      '==================================================');
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

          // Server is the authoritative source - use server data directly
          _cartItems = items;

          // Immediately notify listeners so UI updates with preserved quantities
          notifyListeners();

          // Save to local storage after UI update
          await _saveUserCarts();
        } else {
          debugPrint('Cart sync condition not met');
        }
      } else {
        debugPrint('Cart sync condition not met');
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
        _addToLocalCart(item);
        return;
      }

      // Debug: Print current cart items for comparison
      debugPrint('🔍 CHECKING FOR EXISTING ITEM ===');
      debugPrint(
          'Adding item: ${item.name}, Product ID: ${item.productId}, Batch: ${item.batchNo}');
      debugPrint('Current cart items:');
      for (int i = 0; i < _cartItems.length; i++) {
        final cartItem = _cartItems[i];
        debugPrint(
            '  [$i] ${cartItem.name}, Product ID: ${cartItem.productId}, Server ID: ${cartItem.serverProductId}, Batch: ${cartItem.batchNo}');
      }

      final existingIndex = _cartItems.indexWhere((cartItem) {
        // Prioritize name and batch matching since Product IDs can be inconsistent
        // Use normalized names for more flexible matching
        String normalizedCartName = _normalizeProductName(cartItem.name);
        String normalizedItemName = _normalizeProductName(item.name);
        bool matchByNameAndBatch = (normalizedCartName == normalizedItemName &&
            cartItem.batchNo == item.batchNo);
        bool matchById = (cartItem.productId == item.productId &&
            cartItem.batchNo == item.batchNo);
        bool matchByServerId =
            (cartItem.serverProductId?.toString() == item.productId &&
                cartItem.batchNo == item.batchNo);

        debugPrint(
            '  Checking: ${cartItem.name} - Normalized: $normalizedCartName vs $normalizedItemName');
        debugPrint(
            '  Match by Name: $matchByNameAndBatch, Match by ID: $matchById, Match by Server ID: $matchByServerId');

        // Return true if any match is found, prioritizing name matching
        return matchByNameAndBatch || matchById || matchByServerId;
      });

      debugPrint('Existing index found: $existingIndex');
      debugPrint('=====================================');

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

        _cartItems[existingIndex].updateQuantity(newQuantity);

        // Server is the authoritative source - no protection needed
        debugPrint('✅ ITEM UPDATED LOCALLY - WILL SYNC WITH SERVER ===');
        debugPrint('Product: ${item.name}');
        debugPrint('New Total Quantity: $newQuantity');
        debugPrint('App Product ID: ${item.productId}');
        debugPrint('Server Product ID: ${item.serverProductId}');
        debugPrint('========================================');

        await _saveUserCarts();
        notifyListeners();

        // Try to sync with server in background
        _syncAddToServer(item);
      } else {
        _cartItems.add(item);

        // Server is the authoritative source - no protection needed
        debugPrint('✅ NEW ITEM ADDED LOCALLY - WILL SYNC WITH SERVER ===');
        debugPrint('Product: ${item.name}');
        debugPrint('Quantity: ${item.quantity}');
        debugPrint('App Product ID: ${item.productId}');
        debugPrint('Server Product ID: ${item.serverProductId}');
        debugPrint('============================================');

        await _saveUserCarts();
        notifyListeners();

        // Try to sync with server in background
        _syncAddToServer(item);
      }
    } catch (e) {
      // Any exception, fallback to local cart
      debugPrint('Error adding to cart: $e, adding to local cart');
      _addToLocalCart(item);
    }
  }

  // Background sync for adding to server - DISABLED
  Future<void> _syncAddToServer(CartItem item) async {
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
          debugPrint('[CartProvider] Using Bearer token for cart sync: $token');
        } else if (token.startsWith('guest')) {
          headers['Authorization'] = 'Guest $token';
          debugPrint('[CartProvider] Using Guest token for cart sync: $token');
        } else {
          debugPrint('Token present but not logged in and not a guest_id.');
          return;
        }
      } else {
        debugPrint(
            'Cannot sync add to server - missing auth token and guest_id');
        return;
      }

      // Use the most reliable product ID - prefer serverProductId, fallback to originalProductId, then productId
      int? productIdToUse;
      try {
        if (item.serverProductId != null) {
          productIdToUse = item.serverProductId;
          debugPrint('✅ Using serverProductId: $productIdToUse');
        } else if (item.originalProductId != null) {
          productIdToUse = int.tryParse(item.originalProductId!);
          debugPrint('✅ Using originalProductId: $productIdToUse');
        } else {
          productIdToUse = int.tryParse(item.productId);
          debugPrint('✅ Using productId: $productIdToUse');
        }
      } catch (e) {
        debugPrint('❌ Error parsing product ID: $e');
        productIdToUse = null;
      }

      if (productIdToUse == null) {
        debugPrint('❌ No valid product ID found - cannot add to cart');
        return;
      }

      final requestBody = {
        'productID': productIdToUse,
        'quantity': item.quantity,
      };

      final url = 'https://eclcommerce.ernestchemists.com.gh/api/check-auth';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('=== ADD TO CART API RESPONSE ===');
      debugPrint('URL: $url');
      debugPrint('Request Body:  ${jsonEncode(requestBody)} ');
      debugPrint('Request Headers: $headers');
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Successfully added item to server cart');

        // Store the original product ID before syncing
        final originalProductId = item.productId;
        debugPrint('🔍 PRESERVING ORIGINAL PRODUCT ID FOR SYNC ===');
        debugPrint('Original Product ID: $originalProductId');
        debugPrint('Item Name: ${item.name}');
        debugPrint('=============================================');

        // Store this item's original product ID in a temporary variable for sync
        _pendingOriginalProductId = originalProductId;
        _pendingItemName = item.name;
        _pendingItemBatch = item.batchNo;

        // Sync with server to get the authoritative cart state
        await syncWithApi();

        // After sync, find the item and restore the original product ID
        final syncedItemIndex = _cartItems.indexWhere((cartItem) =>
            _normalizeProductName(cartItem.name) ==
                _normalizeProductName(item.name) &&
            cartItem.batchNo == item.batchNo);

        if (syncedItemIndex != -1) {
          _cartItems[syncedItemIndex] = _cartItems[syncedItemIndex].copyWith(
            originalProductId: originalProductId,
          );
          debugPrint('🔍 RESTORED ORIGINAL PRODUCT ID ===');
          debugPrint('Product: ${_cartItems[syncedItemIndex].name}');
          debugPrint(
              'Original Product ID: ${_cartItems[syncedItemIndex].originalProductId}');
          debugPrint(
              'Server Product ID: ${_cartItems[syncedItemIndex].serverProductId}');
          debugPrint('====================================');
          notifyListeners();
        } else {
          // Try flexible matching for e-panol products if exact match fails
          final flexibleMatchIndex = _cartItems.indexWhere((cartItem) {
            final cartNormalizedName = _normalizeProductName(cartItem.name);
            final itemNormalizedName = _normalizeProductName(item.name);

            // More flexible matching for e-panol products
            final isEpanolCart = cartNormalizedName.contains('e panol') ||
                cartNormalizedName.contains('e-panol');
            final isEpanolItem = itemNormalizedName.contains('e panol') ||
                itemNormalizedName.contains('e-panol');

            if (isEpanolCart && isEpanolItem) {
              // For e-panol products, match by batch number and flavor
              final cartHasStrawberry =
                  cartNormalizedName.contains('strawberry');
              final itemHasStrawberry =
                  itemNormalizedName.contains('strawberry');
              final cartHasOriginal = cartNormalizedName.contains('original');
              final itemHasOriginal = itemNormalizedName.contains('original');

              return cartItem.batchNo == item.batchNo &&
                  ((cartHasStrawberry && itemHasStrawberry) ||
                      (cartHasOriginal && itemHasOriginal));
            }

            return false;
          });

          if (flexibleMatchIndex != -1) {
            _cartItems[flexibleMatchIndex] =
                _cartItems[flexibleMatchIndex].copyWith(
              originalProductId: originalProductId,
            );
            debugPrint('🔍 RESTORED ORIGINAL PRODUCT ID (FLEXIBLE MATCH) ===');
            debugPrint('Product: ${_cartItems[flexibleMatchIndex].name}');
            debugPrint(
                'Original Product ID: ${_cartItems[flexibleMatchIndex].originalProductId}');
            debugPrint(
                'Server Product ID: ${_cartItems[flexibleMatchIndex].serverProductId}');
            debugPrint('==================================================');
            notifyListeners();
          } else {
            debugPrint('🔍 NO MATCHING ITEM FOUND FOR RESTORATION ===');
            debugPrint('Item Name: ${item.name}');
            debugPrint('Original Product ID: $originalProductId');
            debugPrint('Batch: ${item.batchNo}');
            debugPrint('==============================================');
          }
        }
      } else {
        debugPrint(
            'Failed to add/update cart item on server: ${response.statusCode}');

        // Handle specific error cases
        if (response.statusCode == 404) {
          debugPrint('⚠️ Product not found (404) - keeping item locally');
          debugPrint('Product: ${item.name}');
          debugPrint('Product ID: ${item.productId}');
          debugPrint('Server Product ID: ${item.serverProductId}');
          debugPrint('Response: ${response.body}');
          // Keep item locally, don't sync
          return;
        } else if (response.statusCode == 500) {
          debugPrint('⚠️ Server error (500) - keeping item locally');
          debugPrint('Product: ${item.name}');
          debugPrint('Response: ${response.body}');
          // Keep item locally, don't sync
          return;
        }

        // For other errors, still sync to get current server state
        await syncWithApi();
      }
    } catch (e) {
      debugPrint('Error adding/updating cart item on server: $e');
    }
  }

  // Helper method to add item to local cart with proper quantity handling
  void _addToLocalCart(CartItem item) async {
    // Check if item already exists in local cart by product ID, batch number, and name
    final existingIndex = _cartItems.indexWhere((cartItem) =>
        (cartItem.productId == item.productId &&
            cartItem.batchNo == item.batchNo) ||
        (cartItem.batchNo == item.batchNo && cartItem.name == item.name));

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

    _purchasedItems.addAll(_cartItems);
    _cartItems.clear();

    await _saveUserCarts();
    await _savePurchasedItems();
    notifyListeners();
  }

  Future<void> removeFromCart(String cartId) async {
    debugPrint('🗑️ REMOVE FROM CART ===');
    debugPrint('Cart ID to remove: $cartId');
    debugPrint('Current cart items:');
    for (int i = 0; i < _cartItems.length; i++) {
      final item = _cartItems[i];
      debugPrint(
          '  [$i] ID: ${item.id}, Name: ${item.name}, Server ID: ${item.serverProductId}');
    }

    // Find the item to remove
    final itemToRemove = _cartItems.firstWhere(
      (item) => item.id == cartId,
      orElse: () => CartItem(
        id: '',
        productId: '',
        name: '',
        price: 0.0,
        quantity: 0,
        image: '',
        batchNo: '',
        urlName: '',
        totalPrice: 0.0,
      ),
    );

    if (itemToRemove.id.isEmpty) {
      debugPrint('❌ Item not found in cart with ID: $cartId');
      return;
    }

    debugPrint(
        '✅ Found item to remove: ${itemToRemove.name} (ID: ${itemToRemove.id})');

    // Remove from local cart first (works for both logged-in and non-logged-in users)
    _cartItems.removeWhere((item) => item.id == cartId);
    await _saveUserCarts();
    notifyListeners();

    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      try {
        final token = await AuthService.getToken();
        if (token == null) {
          debugPrint('Cannot remove from cart - missing auth token');
          return;
        }

        final response = await http.post(
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'cart_id': cartId,
          }),
        );

        debugPrint('=== REMOVE FROM CART API RESPONSE (user) ===');
        debugPrint(
            'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
        debugPrint('Request Body: ${jsonEncode({'cart_id': cartId})}');
        debugPrint('Request Headers: Bearer $token');
        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Headers: ${response.headers}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('====================================');

        // Always sync with server after removal
        await syncWithApi();
      } catch (e) {
        // Even if there's an error, try to sync with server
        await syncWithApi();
      }
    } else {
      // Guest user: remove from backend using guest_id
      try {
        final prefs = await SharedPreferences.getInstance();
        final guestId = prefs.getString('guest_id');
        if (guestId == null || guestId.isEmpty) {
          debugPrint('Cannot remove from cart - missing guest_id');
          return;
        }
        final response = await http.post(
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart'),
          headers: {
            'Authorization': 'Guest $guestId',
            'X-Guest-ID': guestId,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'cart_id': cartId,
          }),
        );
        debugPrint('=== REMOVE FROM CART API RESPONSE (guest) ===');
        debugPrint(
            'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
        debugPrint('Request Body: ${jsonEncode({'cart_id': cartId})}');
        debugPrint('Request Headers: Guest $guestId, X-Guest-ID: $guestId');
        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Headers: ${response.headers}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('====================================');
        await syncWithApi();
      } catch (e) {
        await syncWithApi();
      }
    }
  }

  // Track ongoing quantity updates to prevent conflicts
  final Map<String, bool> _ongoingUpdates = {};

  // Method to check if an item is currently being updated
  bool isItemUpdating(String itemId) {
    final item = _cartItems.firstWhere(
      (item) => item.id == itemId,
      orElse: () => CartItem(
        id: '',
        productId: '',
        name: '',
        price: 0.0,
        image: '',
        batchNo: '',
        urlName: '',
        totalPrice: 0.0,
      ),
    );

    if (item.id.isEmpty) return false;

    final updateKey = '${item.id}_${item.productId}';
    return _ongoingUpdates[updateKey] == true;
  }

  // Method to check if any item is currently being updated
  bool get isAnyItemUpdating =>
      _ongoingUpdates.values.any((isUpdating) => isUpdating);

  // Method to get count of items being updated
  int get updatingItemsCount =>
      _ongoingUpdates.values.where((isUpdating) => isUpdating).length;

  // New method that uses item ID instead of index
  Future<void> updateQuantityById(String itemId, int newQuantity) async {
    debugPrint('🔍 CartProvider: updateQuantityById called');
    debugPrint('🔍 CartProvider: Item ID: $itemId');
    debugPrint('🔍 CartProvider: New Quantity: $newQuantity');

    // Find item by ID instead of index
    final itemIndex = _cartItems.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      debugPrint('⚠️ Item not found with ID: $itemId');
      return;
    }

    final item = _cartItems[itemIndex];
    final oldQuantity = item.quantity;
    final updateKey = '${item.id}_${item.productId}';

    debugPrint('🔍 CartProvider: Item: ${item.name}');
    debugPrint('🔍 CartProvider: Old Quantity: $oldQuantity');
    debugPrint('🔍 CartProvider: Update Key: $updateKey');
    debugPrint('🔍 CartProvider: Item ID: ${item.id}');
    debugPrint('🔍 CartProvider: Item Name: ${item.name}');

    // Check if there's already an ongoing update for this item
    if (_ongoingUpdates[updateKey] == true) {
      debugPrint('⏳ Update already in progress for ${item.name} - skipping...');
      return;
    }

    debugPrint('=== SIMPLE QUANTITY UPDATE ===');
    debugPrint('Product Name: ${item.name}');
    debugPrint('Old Quantity: $oldQuantity');
    debugPrint('New Quantity: $newQuantity');
    debugPrint('Cart Item ID: ${item.id}');

    // Mark this item as being updated
    _ongoingUpdates[updateKey] = true;

    // Update local state immediately for UI responsiveness
    _cartItems[itemIndex].updateQuantity(newQuantity);
    await _saveUserCarts();
    notifyListeners();

    // Add fallback timer to clear update flag after maximum time
    Timer(const Duration(seconds: 10), () {
      if (_ongoingUpdates[updateKey] == true) {
        debugPrint('⏰ Fallback timer: Clearing update flag for ${item.name}');
        _ongoingUpdates[updateKey] = false;
        notifyListeners();
      }
    });

    debugPrint('✅ Quantity updated locally - will sync with server');

    if (await AuthService.isLoggedIn()) {
      try {
        // Add timeout to prevent infinite loading
        await _simpleQuantityUpdate(item, newQuantity)
            .timeout(const Duration(seconds: 8), onTimeout: () {
          debugPrint('⏰ Update timeout for ${item.name}');
          throw TimeoutException('Update timed out');
        });
      } catch (e) {
        debugPrint('⚠️ Update error for ${item.name}: $e');
        // Show user-friendly error message
        _showSyncError('Update timed out. Please try again.');
      } finally {
        // Always clear the ongoing update flag
        _ongoingUpdates[updateKey] = false;
        debugPrint('✅ Update completed for ${item.name}');
      }
    } else {
      // Clear the flag if not logged in
      _ongoingUpdates[updateKey] = false;
    }
  }

  Future<void> updateQuantity(int index, int newQuantity) async {
    debugPrint('🔍 CartProvider: updateQuantity called');
    debugPrint('🔍 CartProvider: Index: $index');
    debugPrint('🔍 CartProvider: New Quantity: $newQuantity');

    if (index < 0 || index >= _cartItems.length) {
      debugPrint('⚠️ Invalid index for quantity update: $index');
      return;
    }

    final item = _cartItems[index];
    final oldQuantity = item.quantity;
    final updateKey = '${item.id}_${item.productId}';

    debugPrint('🔍 CartProvider: Item: ${item.name}');
    debugPrint('🔍 CartProvider: Old Quantity: $oldQuantity');
    debugPrint('🔍 CartProvider: Update Key: $updateKey');
    debugPrint('🔍 CartProvider: Item ID: ${item.id}');
    debugPrint('🔍 CartProvider: Item Name: ${item.name}');

    // Check if there's already an ongoing update for this item
    if (_ongoingUpdates[updateKey] == true) {
      debugPrint('⏳ Update already in progress for ${item.name} - skipping...');
      return;
    }

    debugPrint('=== SIMPLE QUANTITY UPDATE ===');
    debugPrint('Product Name: ${item.name}');
    debugPrint('Old Quantity: $oldQuantity');
    debugPrint('New Quantity: $newQuantity');
    debugPrint('Cart Item ID: ${item.id}');

    // Mark this item as being updated
    _ongoingUpdates[updateKey] = true;

    // Update local state immediately for UI responsiveness
    _cartItems[index].updateQuantity(newQuantity);
    await _saveUserCarts();
    notifyListeners();

    // Add fallback timer to clear update flag after maximum time
    Timer(const Duration(seconds: 10), () {
      if (_ongoingUpdates[updateKey] == true) {
        debugPrint('⏰ Fallback timer: Clearing update flag for ${item.name}');
        _ongoingUpdates[updateKey] = false;
        notifyListeners();
      }
    });

    debugPrint('✅ Quantity updated locally - will sync with server');

    if (await AuthService.isLoggedIn()) {
      try {
        // Add timeout to prevent infinite loading
        await _simpleQuantityUpdate(item, newQuantity)
            .timeout(const Duration(seconds: 8), onTimeout: () {
          debugPrint('⏰ Update timeout for ${item.name}');
          throw TimeoutException('Update timed out');
        });
      } catch (e) {
        debugPrint('⚠️ Update error for ${item.name}: $e');
        // Show user-friendly error message
        _showSyncError('Update timed out. Please try again.');
      } finally {
        // Always clear the ongoing update flag
        _ongoingUpdates[updateKey] = false;
        debugPrint('✅ Update completed for ${item.name}');
      }
    } else {
      // Clear the flag if not logged in
      _ongoingUpdates[updateKey] = false;
    }
  }

  // Simple quantity update using remove-and-add approach
  Future<void> _simpleQuantityUpdate(CartItem item, int newQuantity) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot sync quantity - missing auth token');
        return;
      }

      debugPrint('🔄 SIMPLE QUANTITY UPDATE: Remove and Add approach');

      // Step 1: Remove the current item from cart
      debugPrint('=== STEP 1: REMOVE CURRENT ITEM ===');
      final removeResponse = await http.post(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'cart_id': item.id}),
      );

      debugPrint('Remove Response: ${removeResponse.statusCode}');
      debugPrint('Remove Body: ${removeResponse.body}');

      // Check if remove was successful
      if (removeResponse.statusCode != 200 &&
          removeResponse.statusCode != 201) {
        debugPrint('❌ Remove operation failed - keeping item locally');
        debugPrint('Status: ${removeResponse.statusCode}');
        debugPrint('Response: ${removeResponse.body}');

        // If remove fails, don't try to add - just keep the item locally
        _showSyncError(
            'Server temporarily unavailable. Item remains in cart with previous quantity.');
        return;
      }

      // Step 2: Add the item back with new quantity
      debugPrint('=== STEP 2: ADD WITH NEW QUANTITY ===');

      // Get the correct product ID - prioritize original product ID for updates
      debugPrint('🔍 PRODUCT ID SELECTION ===');
      debugPrint('Server Product ID: ${item.serverProductId}');
      debugPrint('Original Product ID: ${item.originalProductId}');
      debugPrint('Product ID: ${item.productId}');

      int? productId;

      // For quantity updates, always use original product ID first, then fallback to server product ID
      if (item.originalProductId != null) {
        productId = int.tryParse(item.originalProductId!);
        debugPrint('✅ Using originalProductId: $productId (always preferred)');
      } else if (item.serverProductId != null) {
        productId = item.serverProductId;
        debugPrint('✅ Using serverProductId: $productId (fallback)');
      } else {
        productId = int.tryParse(item.productId);
        debugPrint('✅ Using productId: $productId (last resort)');
      }

      if (productId == null) {
        debugPrint('❌ No valid product ID found');
        debugPrint('All product ID fields are null or invalid');
        return;
      }

      final addRequestBody = {
        'productID': productId,
        'quantity': newQuantity,
      };

      debugPrint('🔍 ADD REQUEST DETAILS ===');
      debugPrint('Product Name: ${item.name}');
      debugPrint('Product ID being sent: $productId');
      debugPrint('Quantity being sent: $newQuantity');
      debugPrint('Request Body: ${jsonEncode(addRequestBody)}');
      debugPrint(
          'Request URL: https://eclcommerce.ernestchemists.com.gh/api/check-auth');
      debugPrint('================================');

      final addResponse = await http.post(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/check-auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(addRequestBody),
      );

      debugPrint('Add Response: ${addResponse.statusCode}');
      debugPrint('Add Body: ${addResponse.body}');

      if (addResponse.statusCode == 200 || addResponse.statusCode == 201) {
        debugPrint('✅ Quantity update successful');

        // Parse the response to check if the correct product was added
        try {
          final responseData = jsonDecode(addResponse.body);
          if (responseData['items'] != null && responseData['items'] is List) {
            final items = responseData['items'] as List;
            if (items.isNotEmpty) {
              final addedItem = items.first;
              final addedProductName =
                  addedItem['product_name']?.toString() ?? '';
              final addedProductId = addedItem['product_id']?.toString() ?? '';

              debugPrint('🔍 VERIFYING ADDED PRODUCT ===');
              debugPrint('Expected Product: ${item.name}');
              debugPrint('Added Product: $addedProductName');
              debugPrint('Expected Product ID: $productId');
              debugPrint('Added Product ID: $addedProductId');

              // Check if the added product matches what we expected
              if (addedProductName.toLowerCase() != item.name.toLowerCase() ||
                  addedProductId != productId.toString()) {
                debugPrint('⚠️ PRODUCT MISMATCH DETECTED ===');
                debugPrint('Backend added different product than requested');
                debugPrint(
                    'This may indicate product substitution or backend issues');

                // Show user-friendly message about product substitution
                _showSyncError(
                    'Product was updated with available alternative. Please check your cart.');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not parse add response: $e');
        }

        // Sync with server to get updated cart state
        await syncWithApi();
      } else if (addResponse.statusCode == 404) {
        debugPrint(
            '⚠️ Product not found (404) - trying alternative product ID');
        debugPrint('Response body: ${addResponse.body}');

        // Try with server product ID as fallback if original product ID failed
        if (item.serverProductId != null &&
            item.serverProductId.toString() != item.originalProductId) {
          debugPrint('🔄 RETRYING WITH SERVER PRODUCT ID ===');
          final serverProductId = item.serverProductId;

          debugPrint('Trying with server product ID: $serverProductId');

          final retryRequestBody = {
            'productID': serverProductId,
            'quantity': newQuantity,
          };

          final retryResponse = await http.post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/check-auth'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(retryRequestBody),
          );

          debugPrint('Retry Response: ${retryResponse.statusCode}');
          debugPrint('Retry Body: ${retryResponse.body}');

          if (retryResponse.statusCode == 200 ||
              retryResponse.statusCode == 201) {
            debugPrint('✅ Quantity update successful with server product ID');
            await syncWithApi();
            return;
          }
        }

        // If all attempts fail, keep the item locally but show error
        debugPrint('❌ All product ID attempts failed - keeping item locally');
        _showSyncError(
            'Quantity update failed. Item remains in cart with previous quantity.');
        // Don't sync with server as it might remove the item
      } else {
        debugPrint('❌ Failed to update quantity on server');
        debugPrint('Response status: ${addResponse.statusCode}');
        debugPrint('Response body: ${addResponse.body}');

        _showSyncError(
            'Quantity update failed. Item remains in cart with previous quantity.');
        // Don't sync with server as it might remove the item
      }
    } catch (e) {
      debugPrint('❌ Error in simple quantity update: $e');

      _showSyncError(
          'Server temporarily unavailable. Item remains in cart with previous quantity.');
      // Don't sync with server as it might remove the item
    }
  }

  // Show user-friendly error message
  void _showSyncError(String message) {
    debugPrint('🔄 Sync Error: $message');
    // Note: In a real app, you might want to show a snackbar or notification
    // For now, we'll just log the error
  }

  // Validate if product is still available on server
  Future<bool> _validateProductAvailability(String productId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      debugPrint('🔍 VALIDATING PRODUCT AVAILABILITY ===');
      debugPrint('Product ID to validate: $productId');
      debugPrint(
          'Validation URL: https://eclcommerce.ernestchemists.com.gh/api/product/$productId');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/product/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      debugPrint('Validation Response Status: ${response.statusCode}');
      debugPrint('Validation Response Body: ${response.body}');
      debugPrint('Product available: ${response.statusCode == 200}');
      debugPrint('=====================================');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Product validation error: $e');
      return false;
    }
  }

  void clearCart() async {
    if (_currentUserId == null) return;

    _cartItems.clear();
    await _saveUserCarts();
    notifyListeners();
  }

  double calculateTotal() {
    return _cartItems.fold(
        0, (total, item) => total + (item.price * item.quantity));
  }

  double calculateSubtotal() {
    return _cartItems.fold(
        0, (subtotal, item) => subtotal + (item.price * item.quantity));
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
    notifyListeners();
  }

  Future<void> refreshLoginStatus() async {
    await _checkCurrentUser();
  }

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

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
      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-out/${await AuthService.getHashedLink()}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['cart_items'] != null) {
          // Remove each item from server
          final serverItems = data['cart_items'] as List;
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
      await http.delete(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-out/$itemId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ Remove from server error: $e');
    }
  }
}
