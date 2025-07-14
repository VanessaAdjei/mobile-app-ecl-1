// pages/cartprovider.dart
import 'package:flutter/foundation.dart';
import 'CartItem.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;

class CartProvider with ChangeNotifier {
  // Map to store carts for different users
  Map<String, List<CartItem>> _userCarts = {};
  // Current user's cart items
  List<CartItem> _cartItems = [];
  List<CartItem> _purchasedItems = [];
  String? _currentUserId;

  // Track recently corrected items to prevent sync override
  // Use normalized product name + batch number as key to avoid product ID mismatches
  Map<String, int> _recentlyCorrectedItems = {};

  // Helper method to normalize product names for consistent key generation
  String _normalizeProductName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim()
        .replaceAll(' ', ''); // Remove all spaces for exact matching
  }

  List<CartItem> get cartItems => _cartItems;
  List<CartItem> get purchasedItems => _purchasedItems;
  String? get currentUserId => _currentUserId;

  CartProvider() {
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    await _loadUserCarts();
    await _checkCurrentUser();
    // Disable automatic server sync to prevent quantity override
    // Local cart is now the source of truth
    // Server sync will happen during checkout
  }

  Future<void> _checkCurrentUser() async {
    bool isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      String userId = (await AuthService.getCurrentUserID()) as String;
      _currentUserId = userId;
      _loadCurrentUserCart();
    } else {
      _currentUserId = null;
      // For non-logged-in users, maintain a local cart
      // This allows users to add items before logging in
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
    } else if (_currentUserId == null && _userCarts.containsKey('guest')) {
      // Load guest cart for non-logged-in users
      _cartItems = _userCarts['guest']!;
    } else {
      _cartItems = [];
    }

    // Load purchased items for current user
    _loadPurchasedItems();
  }

  Future<void> _saveUserCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update current user's cart in the map if logged in
      if (_currentUserId != null) {
        _userCarts[_currentUserId!] = _cartItems;
      } else {
        // For non-logged-in users, save to a special key
        _userCarts['guest'] = _cartItems;
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
      ).timeout(const Duration(seconds: 10)); // Add timeout

      print('=== SYNC CART API RESPONSE ===');
      print(
          'URL: https://eclcommerce.ernestchemists.com.gh/api/check-out/$hashedLink');
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('=============================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('=== SYNC CART PARSED DATA ===');
        print('Cart Items: ${data['cart_items']}');
        print('Data Keys: ${data.keys.toList()}');
        print('============================');

        if (data['cart_items'] != null) {
          final rawItems = data['cart_items'] as List;

          // If server cart is empty but we have local items, preserve local cart
          if (rawItems.isEmpty && _cartItems.isNotEmpty) {
            print('⚠️ SERVER CART EMPTY - PRESERVING LOCAL CART ===');
            print(
                'Server returned empty cart but local cart has ${_cartItems.length} items');
            print('Preserving local cart items to prevent data loss');
            print('Protected items: ${_recentlyCorrectedItems.keys.toList()}');
            print('================================================');

            // Keep existing cart items and just notify listeners
            notifyListeners();
            return;
          }

          // Merge duplicate items by product_id and batch number
          Map<String, CartItem> mergedItems = {};

          for (final rawItem in rawItems) {
            final cartItem = CartItem.fromServerJson(rawItem);
            final productId = cartItem.productId;
            final batchNo = cartItem.batchNo;
            final key = '$productId-$batchNo'; // Use product ID + batch as key

            if (mergedItems.containsKey(key)) {
              // Item already exists, add quantities
              final existingItem = mergedItems[key]!;
              final newQuantity = existingItem.quantity + cartItem.quantity;
              existingItem.updateQuantity(newQuantity);
              print('🔍 MERGED DUPLICATE ITEM ===');
              print('Product: ${cartItem.name}');
              print('Batch: $batchNo');
              print('Old Quantity: ${cartItem.quantity}');
              print('New Total Quantity: $newQuantity');
              print('===========================');
            } else {
              // New item, add to map
              mergedItems[key] = cartItem;
            }
          }

          // Apply protection for recently corrected items using product name + batch
          print('🔍 PROTECTION DEBUG ===');
          print('Recently corrected items: $_recentlyCorrectedItems');
          print('Merged items count: ${mergedItems.length}');

          for (final item in mergedItems.values) {
            final normalizedName = _normalizeProductName(item.name);
            final protectionKey = '$normalizedName-${item.batchNo}';
            print('Checking protection for: $protectionKey');
            print('Item name: ${item.name}');
            print('Normalized name: $normalizedName');
            print('Item batch: ${item.batchNo}');

            if (_recentlyCorrectedItems.containsKey(protectionKey)) {
              final localQuantity = _recentlyCorrectedItems[protectionKey]!;
              print('🔒 APPLYING PROTECTION ===');
              print('Product: ${item.name}');
              print('Server Quantity: ${item.quantity}');
              print('Protected Quantity: $localQuantity');
              print('Protection Key: $protectionKey');
              print('==========================');
              item.updateQuantity(localQuantity);
            } else {
              print('❌ No protection found for: $protectionKey');
            }
          }
          print('🔍 END PROTECTION DEBUG ===');

          final items = mergedItems.values.toList();

          // Debug total price calculation
          double calculatedTotal = items.fold(
              0.0, (sum, item) => sum + (item.price * item.quantity));
          double apiTotal = (data['total_price'] ?? 0.0).toDouble();

          // If totals don't match, try to correct quantities based on total price
          if (calculatedTotal != apiTotal) {
            if (items.length == 1) {
              // Single item - correct its quantity
              final item = items.first;
              final key = '${item.productId}-${item.batchNo}';

              // Check if this item was recently corrected
              final normalizedName = _normalizeProductName(item.name);
              final protectionKey = '$normalizedName-${item.batchNo}';
              if (_recentlyCorrectedItems.containsKey(protectionKey)) {
                final trackedQuantity = _recentlyCorrectedItems[protectionKey]!;
                if (item.quantity != trackedQuantity) {
                  print('Single Item - Using Tracked Quantity:');
                  print('Product: ${item.name}');
                  print('Normalized Name: $normalizedName');
                  print('API Qty: ${item.quantity}');
                  print('Tracked Qty: $trackedQuantity');
                  print('Protection Key: $protectionKey');
                  item.updateQuantity(trackedQuantity);
                }
              } else {
                // Use total price calculation
                final correctQuantity = (apiTotal / item.price).round();
                if (correctQuantity > 0 && correctQuantity != item.quantity) {
                  item.updateQuantity(correctQuantity);
                }
              }
            } else {
              // Multiple items - try to identify which one needs correction
              for (final item in items) {
                final key = '${item.productId}-${item.batchNo}';

                // Check if this item was recently corrected
                final normalizedName = _normalizeProductName(item.name);
                final protectionKey = '$normalizedName-${item.batchNo}';
                if (_recentlyCorrectedItems.containsKey(protectionKey)) {
                  final trackedQuantity =
                      _recentlyCorrectedItems[protectionKey]!;
                  if (item.quantity != trackedQuantity) {
                    print('Multiple Items - Using Tracked Quantity:');
                    print('Product: ${item.name}');
                    print('Normalized Name: $normalizedName');
                    print('API Qty: ${item.quantity}');
                    print('Tracked Qty: $trackedQuantity');
                    print('Protection Key: $protectionKey');
                    item.updateQuantity(trackedQuantity);
                  }
                } else {
                  // Use total price calculation
                  final itemTotal = item.price * item.quantity;
                  final itemApiTotal = item.totalPrice;

                  if (itemTotal != itemApiTotal) {
                    final correctQuantity = (itemApiTotal / item.price).round();
                    if (correctQuantity > 0 &&
                        correctQuantity != item.quantity) {
                      item.updateQuantity(correctQuantity);
                    }
                  }
                }
              }
            }
          }

          final finalItems = <CartItem>[];

          for (final serverItem in items) {
            final normalizedName = _normalizeProductName(serverItem.name);
            final protectionKey = '$normalizedName-${serverItem.batchNo}';

            // Check if this item was recently updated locally
            if (_recentlyCorrectedItems.containsKey(protectionKey)) {
              final localQuantity = _recentlyCorrectedItems[protectionKey]!;

              print('🔒 FINAL PROTECTION CHECK ===');
              print('Product: ${serverItem.name}');
              print('Normalized Name: $normalizedName');
              print('Server Quantity: ${serverItem.quantity}');
              print('Protected Quantity: $localQuantity');
              print('Protection Key: $protectionKey');
              print('=============================');

              // Use local quantity instead of server quantity
              serverItem.updateQuantity(localQuantity);
            }

            finalItems.add(serverItem);
          }

          _cartItems = finalItems;

          // Immediately notify listeners so UI updates with preserved quantities
          notifyListeners();

          // Save to local storage after UI update
          await _saveUserCarts();
        } else {}
      } else {}
    } catch (e) {}
  }

  Future<bool> _verifyProductExists(String urlName, String batchNo) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/product-details/$urlName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final productData = data['data']['product'] ?? {};
          final inventoryData = data['data']['inventory'] ?? {};

          // Check if product exists and batch number matches
          final productBatchNo =
              inventoryData['batch_no'] ?? productData['batch_no'];
          final exists = productData != null && productBatchNo == batchNo;

          return exists;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> addToCart(CartItem item) async {
    // For logged-in users, try to sync with server
    _currentUserId ??= await AuthService.getCurrentUserID();

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        // Fallback to local cart if no token
        debugPrint(
            'Cannot add to cart - missing auth token, adding to local cart');
        _addToLocalCart(item);
        return;
      }

      final existingIndex = _cartItems.indexWhere((cartItem) =>
          (cartItem.productId == item.productId &&
              cartItem.batchNo == item.batchNo) ||
          (cartItem.serverProductId?.toString() == item.productId &&
              cartItem.batchNo == item.batchNo));

      if (existingIndex != -1) {
        // Item exists, add to existing quantity
        final oldQuantity = _cartItems[existingIndex].quantity;
        final newQuantity = oldQuantity + item.quantity;

        print('🔍 ITEM EXISTS - ADDING TO QUANTITY ===');
        print('Product: ${item.name}');
        print('Old Quantity: $oldQuantity');
        print('Adding Quantity: ${item.quantity}');
        print('New Total Quantity: $newQuantity');
        print('=====================================');

        _cartItems[existingIndex].updateQuantity(newQuantity);

        // Mark this item as recently corrected to prevent sync override
        // Use normalized product name + batch number as key to avoid product ID mismatches
        final normalizedName = _normalizeProductName(item.name);
        final protectionKey = '$normalizedName-${item.batchNo}';
        _recentlyCorrectedItems[protectionKey] = item.quantity;
        print('🔒 PROTECTED ITEM FROM SYNC OVERRIDE ===');
        print('Product: ${item.name}');
        print('Normalized Name: $normalizedName');
        print('Quantity: ${item.quantity}');
        print('App Product ID: ${item.productId}');
        print('Server Product ID: ${item.serverProductId}');
        print('Protection Key: $protectionKey');
        print('========================================');

        await _saveUserCarts();
        notifyListeners();

        // Try to sync with server in background
        _syncAddToServer(item);
      } else {
        _cartItems.add(item);

        // Mark this item as recently corrected to prevent sync override
        // Use normalized product name + batch number as key to avoid product ID mismatches
        final normalizedName = _normalizeProductName(item.name);
        final protectionKey = '$normalizedName-${item.batchNo}';
        _recentlyCorrectedItems[protectionKey] = item.quantity;
        print('🔒 PROTECTED NEW ITEM FROM SYNC OVERRIDE ===');
        print('Product: ${item.name}');
        print('Normalized Name: $normalizedName');
        print('Quantity: ${item.quantity}');
        print('App Product ID: ${item.productId}');
        print('Server Product ID: ${item.serverProductId}');
        print('Protection Key: $protectionKey');
        print('============================================');

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
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot sync add to server - missing auth token');
        return;
      }

      final requestBody = {
        'productID': item.serverProductId ?? int.parse(item.productId),
        'quantity': item.quantity,
      };

      final url = 'https://eclcommerce.ernestchemists.com.gh/api/check-auth';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('=== ADD TO CART API RESPONSE ===');
      print('URL: $url');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Optionally sync with server to ensure consistency
        await syncWithApi();
      } else {
        debugPrint('Failed to add/update cart item on server: \\${response.statusCode}');
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
      // Item exists, replace quantity with the new quantity from item detail page
      print('🔍 UPDATING LOCAL CART ITEM ===');
      print('Product: ${item.name}');
      print('Old Quantity: ${_cartItems[existingIndex].quantity}');
      print('New Quantity: ${item.quantity}');
      print('==============================');

      _cartItems[existingIndex].updateQuantity(item.quantity);
    } else {
      // Item doesn't exist, add it
      print('🔍 ADDING NEW ITEM TO LOCAL CART ===');
      print('Product: ${item.name}');
      print('Quantity: ${item.quantity}');
      print('===================================');

      _cartItems.add(item);
    }

    await _saveUserCarts();
    notifyListeners();
  }

  // Helper method to update cart item quantity on server
  Future<void> _updateCartItemOnServer(CartItem item) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot update cart item - missing auth token');
        return;
      }

      final requestBody = {
        'url_name': item.urlName,
        'quantity': item.quantity,
        'batch_no': item.batchNo,
      };

      final url = 'https://eclcommerce.ernestchemists.com.gh/api/check-auth';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('=== UPDATE CART ITEM API RESPONSE ===');
      print('URL: $url');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('=====================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Sync with server to ensure consistency
        await syncWithApi();
      } else {
        debugPrint(
            'Failed to update cart item on server: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating cart item on server: $e');
    }
  }

  void purchaseItems() async {
    if (_currentUserId == null) return;

    _purchasedItems.addAll(_cartItems);
    _cartItems.clear();

    await _saveUserCarts();
    await _savePurchasedItems();
    await _pushCartToServer();
    notifyListeners();
  }

  Future<void> removeFromCart(String cartId) async {
    // Remove from local cart first (works for both logged-in and non-logged-in users)
    _cartItems.removeWhere((item) => item.id == cartId);
    await _saveUserCarts();
    notifyListeners();

    // Only sync with server if user is logged in
    if (await AuthService.isLoggedIn()) {
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

        print('=== REMOVE FROM CART API RESPONSE ===');
        print(
            'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
        print('Request Body: ${jsonEncode({'cart_id': cartId})}');
        print('Response Status: ${response.statusCode}');
        print('Response Headers: ${response.headers}');
        print('Response Body: ${response.body}');
        print('====================================');

        // Always sync with server after removal
        await syncWithApi();
      } catch (e) {
        // Even if there's an error, try to sync with server
        await syncWithApi();
      }
    }
  }

  void updateQuantity(int index, int newQuantity) async {
    // Update local state for both logged-in and non-logged-in users
    if (index >= 0 && index < _cartItems.length) {
      final item = _cartItems[index];
      final currentQuantity = item.quantity;

      print('=== UPDATE QUANTITY - BACKGROUND SYNC ===');
      print('Product Name: ${item.name}');
      print('Old Quantity: $currentQuantity');
      print('New Quantity: $newQuantity');

      // Track this item as recently updated to prevent sync override
      // Use normalized product name + batch number as key to avoid product ID mismatches
      final normalizedName = _normalizeProductName(item.name);
      final protectionKey = '$normalizedName-${item.batchNo}';
      _recentlyCorrectedItems[protectionKey] = newQuantity;

      // Update local state immediately for UI responsiveness
      _cartItems[index].updateQuantity(newQuantity);
      await _saveUserCarts();
      notifyListeners();

      print('✅ Quantity updated locally - item stays in UI');
      print('🔒 Protected from sync override with key: $protectionKey');

      // Try to sync with server in the background (non-blocking)
      if (await AuthService.isLoggedIn()) {
        _syncQuantityWithServer(item, newQuantity);
      }
    }
  }

  // Background sync method that doesn't affect the UI
  Future<void> _syncQuantityWithServer(CartItem item, int newQuantity) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot sync quantity - missing auth token');
        return;
      }

      print('🔄 Background sync: Attempting to update server...');

      // Try to update the server without removing the item from UI
      final requestBody = {
        'productID': item.serverProductId ?? int.parse(item.productId),
        'quantity': newQuantity,
        'batch_no': item.batchNo,
      };

      final response = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/check-auth'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Background sync successful');
        // Clear protection after successful sync
        final normalizedName = _normalizeProductName(item.name);
        final protectionKey = '$normalizedName-${item.batchNo}';
        _recentlyCorrectedItems.remove(protectionKey);
        print('🔓 Removed protection for key: $protectionKey');
      } else {
        print('⚠️ Background sync failed: ${response.statusCode}');
        print('Local changes preserved - will sync during checkout');
        // Keep protection for failed syncs
      }
    } catch (e) {
      debugPrint('Background sync error: $e');
      print('⚠️ Background sync failed - local changes preserved');
    }
  }

  void clearCart() async {
    if (_currentUserId == null) return;

    _cartItems.clear();
    await _saveUserCarts();
    await _pushCartToServer();
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
    // Always sync with server on login
    await syncWithApi();
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

  Future<void> _pushCartToServer() async {
    if (_currentUserId == null) return;
    final items = _cartItems.map((item) => item.toJson()).toList();
    // await AuthService.updateServerCart(items); // Commented out - endpoint doesn't exist
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

  // Merge guest cart into user cart after login
  Future<void> mergeGuestCartOnLogin(String userId) async {
    final guestCart = _userCarts['guest'] ?? [];
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

    _userCarts[userId] = merged.values.toList();
    _cartItems = _userCarts[userId]!;
    _userCarts.remove('guest');
    await _saveUserCarts();
    notifyListeners();
    // Optionally, push merged cart to server here
    // await _pushCartToServer();
  }
}
