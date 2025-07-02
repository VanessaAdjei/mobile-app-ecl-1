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
  Map<String, int> _recentlyCorrectedItems = {};

  List<CartItem> get cartItems => _cartItems;
  List<CartItem> get purchasedItems => _purchasedItems;
  String? get currentUserId => _currentUserId;

  CartProvider() {
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    await _loadUserCarts();
    await _checkCurrentUser();
    // If logged in, always sync with server
    if (_currentUserId != null) {
      await syncWithApi();
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

          for (final key in mergedItems.keys) {
            if (_recentlyCorrectedItems.containsKey(key)) {
              final localQuantity = _recentlyCorrectedItems[key]!;
              final item = mergedItems[key]!;
              print('🔄 OVERRIDING MERGED QUANTITY - PROTECTED ITEM ===');
              print('Product: ${item.name}');
              print('Merged Qty: ${item.quantity}');
              print('Local Qty: $localQuantity');
              print('Using Local Qty: $localQuantity');
              print('=================================================');
              item.updateQuantity(localQuantity);
            }
          }

          final items = mergedItems.values.toList();

          print('=== SYNC CART PROCESSED ITEMS ===');
          print('Raw items from server: ${rawItems.length}');
          print('Merged items: ${items.length}');
          print(
              'Items: ${items.map((item) => '${item.name} (${item.quantity})').toList()}');

          // Debug total price calculation
          double calculatedTotal = items.fold(
              0.0, (sum, item) => sum + (item.price * item.quantity));
          double apiTotal = (data['total_price'] ?? 0.0).toDouble();
          print('Calculated Total: $calculatedTotal');
          print('API Total: $apiTotal');
          print('Total Match: ${calculatedTotal == apiTotal}');

          // If totals don't match, try to correct quantities based on total price
          if (calculatedTotal != apiTotal) {
            print('🔍 CORRECTING QUANTITIES ===');
            print('Calculated Total: $calculatedTotal');
            print('API Total: $apiTotal');

            if (items.length == 1) {
              // Single item - correct its quantity
              final item = items.first;
              final key = '${item.productId}-${item.batchNo}';

              // Check if this item was recently corrected
              if (_recentlyCorrectedItems.containsKey(key)) {
                final trackedQuantity = _recentlyCorrectedItems[key]!;
                if (item.quantity != trackedQuantity) {
                  print('Single Item - Using Tracked Quantity:');
                  print('Product: ${item.name}');
                  print('API Qty: ${item.quantity}');
                  print('Tracked Qty: $trackedQuantity');
                  item.updateQuantity(trackedQuantity);
                }
              } else {
                // Use total price calculation
                final correctQuantity = (apiTotal / item.price).round();
                if (correctQuantity > 0 && correctQuantity != item.quantity) {
                  print('Single Item Correction:');
                  print('Product: ${item.name}');
                  print('API Qty: ${item.quantity}');
                  print('Calculated Qty: $correctQuantity');
                  print('API Total: $apiTotal');
                  print('Item Price: ${item.price}');
                  item.updateQuantity(correctQuantity);
                }
              }
            } else {
              // Multiple items - try to identify which one needs correction
              for (final item in items) {
                final key = '${item.productId}-${item.batchNo}';

                // Check if this item was recently corrected
                if (_recentlyCorrectedItems.containsKey(key)) {
                  final trackedQuantity = _recentlyCorrectedItems[key]!;
                  if (item.quantity != trackedQuantity) {
                    print('Multi-Item - Using Tracked Quantity:');
                    print('Product: ${item.name}');
                    print('API Qty: ${item.quantity}');
                    print('Tracked Qty: $trackedQuantity');
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
                      print('Multi-Item Correction:');
                      print('Product: ${item.name}');
                      print('API Qty: ${item.quantity}');
                      print('Calculated Qty: $correctQuantity');
                      print('Item Total: $itemTotal');
                      print('API Item Total: $itemApiTotal');
                      print('Item Price: ${item.price}');
                      item.updateQuantity(correctQuantity);
                    }
                  }
                }
              }
            }
            print('==========================');
          }
          print('==================================');

          // Merge server items with local changes, preserving recently updated quantities
          final finalItems = <CartItem>[];

          for (final serverItem in items) {
            final key = '${serverItem.productId}-${serverItem.batchNo}';

            // Check if this item was recently updated locally
            if (_recentlyCorrectedItems.containsKey(key)) {
              final localQuantity = _recentlyCorrectedItems[key]!;
              print('🔄 MERGING ITEM - PRESERVING LOCAL QUANTITY ===');
              print('Product: ${serverItem.name}');
              print('Server Qty: ${serverItem.quantity}');
              print('Local Qty: $localQuantity');
              print('Using Local Qty: $localQuantity');
              print('===============================================');

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
        } else {
          debugPrint('No cart items in API response');
          print('=== SYNC CART - NO ITEMS FOUND ===');
          print('Available keys: ${data.keys.toList()}');
          print('Full response: ${json.encode(data)}');
          print('===================================');
        }
      } else {
        debugPrint('Failed to sync cart: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing cart with API: $e');
    }
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
    print('=== ADD TO CART - SIMPLIFIED ===');
    print('Product: ${item.name}');
    print('Quantity: ${item.quantity}');
    print('Product ID: ${item.productId}');
    print('Batch: ${item.batchNo}');
    print('===============================');

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

      // Check if item already exists in local cart
      final existingIndex = _cartItems.indexWhere((cartItem) =>
          cartItem.productId == item.productId &&
          cartItem.batchNo == item.batchNo);

      if (existingIndex != -1) {
        // Item exists, update quantity
        print('🔍 ITEM EXISTS - UPDATING QUANTITY ===');
        print('Product: ${item.name}');
        print('Old Quantity: ${_cartItems[existingIndex].quantity}');
        print('New Quantity: ${item.quantity}');
        print('=====================================');

        _cartItems[existingIndex].updateQuantity(item.quantity);
        await _saveUserCarts();
        notifyListeners();

        // Try to sync with server in background
        _syncAddToServer(item);
      } else {
        // Item doesn't exist, add it locally first
        print('🔍 NEW ITEM - ADDING TO CART ===');
        print('Product: ${item.name}');
        print('Quantity: ${item.quantity}');
        print('===============================');

        _cartItems.add(item);
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

  // Background sync for adding to server
  Future<void> _syncAddToServer(CartItem item) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot sync add to server - missing auth token');
        return;
      }

      print('🔄 SYNC ADD TO SERVER ===');
      print('Product: ${item.name}');
      print('Quantity: ${item.quantity}');
      print('========================');

      final requestBody = {
        'productID': int.parse(item.productId),
        'quantity': item.quantity,
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

      print('=== SYNC ADD API RESPONSE ===');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('=============================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Add to server successful');
        // Sync cart to get updated server data
        await syncWithApi();
      } else {
        print('⚠️ Add to server failed: ${response.statusCode}');
        print('Local changes preserved - will sync during checkout');
      }
    } catch (e) {
      debugPrint('Error syncing add to server: $e');
      print('⚠️ Add to server failed - local changes preserved');
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
      final key = '${item.productId}-${item.batchNo}';
      _recentlyCorrectedItems[key] = newQuantity;

      // Update local state immediately for UI responsiveness
      _cartItems[index].updateQuantity(newQuantity);
      await _saveUserCarts();
      notifyListeners();

      print('✅ Quantity updated locally - item stays in UI');
      print('🔒 Protected from sync override with key: $key');

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
        final key = '${item.productId}-${item.batchNo}';
        _recentlyCorrectedItems.remove(key);
        print('🔓 Removed protection for key: $key');
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
}
