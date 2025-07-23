// pages/cartprovider.dart
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
    // First normalize: lowercase, replace hyphens with spaces, remove special chars, normalize spaces
    String normalized = name
        .toLowerCase()
        .replaceAll('-', ' ') // Replace hyphens with spaces first
        .replaceAll(RegExp(r'[^a-z0-9\s]'),
            '') // Remove special characters (but keep spaces)
        .replaceAll(
            RegExp(r'\s+'), ' ') // Normalize multiple spaces to single space
        .trim();

    // Split into words and sort alphabetically to handle word order variations
    List<String> words =
        normalized.split(' ').where((word) => word.isNotEmpty).toList();
    words.sort(); // Sort alphabetically

    // Join back together without spaces for exact matching
    String result = words.join('');

    print('🔤 NORMALIZE PRODUCT NAME ===');
    print('Original: "$name"');
    print('Normalized: "$normalized"');
    print('Words: $words');
    print('Result: "$result"');
    print('=============================');

    return result;
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
    } else if (_currentUserId == null && _userCarts.containsKey('guest_id')) {
      // Load guest cart for non-logged-in users
      _cartItems = _userCarts['guest_id']!;
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
      ).timeout(const Duration(seconds: 10)); // Add timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['cart_items'] != null) {
          final rawItems = data['cart_items'] as List;

          // If server cart is empty but we have local items, preserve local cart
          if (rawItems.isEmpty && _cartItems.isNotEmpty) {
            // Keep existing cart items and just notify listeners
            notifyListeners();
            return;
          }

          // Don't merge items - keep them separate for individual removal
          List<CartItem> items = [];

          for (final rawItem in rawItems) {
            var cartItem = CartItem.fromServerJson(rawItem);

            // Check if we have a local item with the same name and batch to preserve original product ID
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
              print('🔍 PRESERVED ORIGINAL PRODUCT ID ===');
              print('Product: ${cartItem.name}');
              print('Original Product ID: ${cartItem.originalProductId}');
              print('Server Product ID: ${cartItem.productId}');
              print('Local Item Product ID: ${matchingLocalItem.productId}');
              print('====================================');
            } else {
              print('🔍 NO LOCAL ITEM FOUND FOR PRESERVATION ===');
              print('Product: ${cartItem.name}');
              print('Batch: ${cartItem.batchNo}');
              print('Server Product ID: ${cartItem.productId}');
              print('==========================================');
            }

            items.add(cartItem);
          }

          print('🔍 PROTECTION DEBUG ===');
          print('Recently corrected items: $_recentlyCorrectedItems');
          print('Items count: ${items.length}');

          for (final item in items) {
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
              // Always use local quantity when protection is active
              item.updateQuantity(localQuantity);
              print('✅ Applied local quantity: $localQuantity');
            } else {
              print('No protection found for: $protectionKey');
            }
          }
          print('🔍 END PROTECTION DEBUG ===');

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

              // Always use local quantity when protection is active
              serverItem.updateQuantity(localQuantity);
              print('✅ Final protection applied: $localQuantity');
            }

            finalItems.add(serverItem);
          }

          _cartItems = finalItems;

          // Clear protection after a delay to allow background sync to complete
          Future.delayed(Duration(seconds: 2), () {
            print('🔓 Clearing protection map: $_recentlyCorrectedItems');
            _recentlyCorrectedItems.clear();
            print('🔓 Cleared all protection after delay');
          });

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
    print('🚀 ADD TO CART METHOD CALLED ===');
    print('Cart items count before adding: ${_cartItems.length}');
    print('Adding item: ${item.name}');
    print('================================');

    // For logged-in users, try to sync with server
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
        debugPrint('[CartProvider] Created guest_id: ' + guestId);
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
      print('🔍 CHECKING FOR EXISTING ITEM ===');
      print(
          'Adding item: ${item.name}, Product ID: ${item.productId}, Batch: ${item.batchNo}');
      print('Current cart items:');
      for (int i = 0; i < _cartItems.length; i++) {
        final cartItem = _cartItems[i];
        print(
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

        print(
            '  Checking: ${cartItem.name} - Normalized: $normalizedCartName vs $normalizedItemName');
        print(
            '  Match by Name: $matchByNameAndBatch, Match by ID: $matchById, Match by Server ID: $matchByServerId');

        // Return true if any match is found, prioritizing name matching
        return matchByNameAndBatch || matchById || matchByServerId;
      });

      print('Existing index found: $existingIndex');
      print('=====================================');

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
        _recentlyCorrectedItems[protectionKey] =
            newQuantity; // Use newQuantity instead of item.quantity
        print('🔒 PROTECTED ITEM FROM SYNC OVERRIDE ===');
        print('Product: ${item.name}');
        print('Normalized Name: $normalizedName');
        print('New Total Quantity: $newQuantity');
        print('App Product ID: ${item.productId}');
        print('Server Product ID: ${item.serverProductId}');
        print('Protection Key: $protectionKey');
        print('Current protection map: $_recentlyCorrectedItems');
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
        print('Current protection map: $_recentlyCorrectedItems');
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
      String? token = await AuthService.getToken();
      Map<String, String> headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      bool isLoggedIn = await AuthService.isLoggedIn();
      if (token != null) {
        if (isLoggedIn) {
          headers['Authorization'] = 'Bearer $token';
          print('[CartProvider] Using Bearer token for cart sync: $token');
        } else if (token.startsWith('guest')) {
          headers['Authorization'] = 'Guest $token';
          print('[CartProvider] Using Guest token for cart sync: $token');
        } else {
          debugPrint('Token present but not logged in and not a guest_id.');
          return;
        }
      } else {
        debugPrint(
            'Cannot sync add to server - missing auth token and guest_id');
        return;
      }

      final requestBody = {
        'productID': item.serverProductId ?? int.parse(item.productId),
        'quantity': item.quantity,
      };

      final url = 'https://eclcommerce.ernestchemists.com.gh/api/check-auth';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('=== ADD TO CART API RESPONSE ===');
      print('URL: $url');
      print('Request Body:  ${jsonEncode(requestBody)} ');
      print('Request Headers: $headers');
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Successfully added item to server cart');
        // Sync with server to get the updated cart with proper server IDs
        await syncWithApi();
      } else {
        debugPrint(
            'Failed to add/update cart item on server: ${response.statusCode}');
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

      print('🔍 UPDATING LOCAL CART ITEM ===');
      print('Product: ${item.name}');
      print('Old Quantity: $oldQuantity');
      print('Adding Quantity: ${item.quantity}');
      print('New Total Quantity: $newQuantity');
      print('==============================');

      _cartItems[existingIndex].updateQuantity(newQuantity);
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
        // Don't sync immediately - let the protection mechanism handle it
        debugPrint('Successfully updated item on server cart');
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
    print('🗑️ REMOVE FROM CART ===');
    print('Cart ID to remove: $cartId');
    print('Current cart items:');
    for (int i = 0; i < _cartItems.length; i++) {
      final item = _cartItems[i];
      print(
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
      print('❌ Item not found in cart with ID: $cartId');
      return;
    }

    print(
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

        print('=== REMOVE FROM CART API RESPONSE (user) ===');
        print(
            'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
        print('Request Body: ${jsonEncode({'cart_id': cartId})}');
        print('Request Headers: Bearer $token');
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
        print('=== REMOVE FROM CART API RESPONSE (guest) ===');
        print(
            'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
        print('Request Body: ${jsonEncode({'cart_id': cartId})}');
        print('Request Headers: Guest $guestId, X-Guest-ID: $guestId');
        print('Response Status: ${response.statusCode}');
        print('Response Headers: ${response.headers}');
        print('Response Body: ${response.body}');
        print('====================================');
        await syncWithApi();
      } catch (e) {
        await syncWithApi();
      }
    }
  }

  Future<void> updateQuantity(int index, int newQuantity) async {
    if (index < 0 || index >= _cartItems.length) {
      print('⚠️ Invalid index for quantity update: $index');
      return;
    }

    final item = _cartItems[index];
    final oldQuantity = item.quantity;
    final isIncrease = newQuantity > oldQuantity;

    print('=== UPDATE QUANTITY - BACKGROUND SYNC ===');
    print('Product Name: ${item.name}');
    print('Old Quantity: $oldQuantity');
    print('New Quantity: $newQuantity');
    print('Cart Item ID: ${item.id}');
    print('Operation: ${isIncrease ? 'INCREASE' : 'DECREASE'}');

    // Create protection key to prevent sync override
    final normalizedName = _normalizeProductName(item.name);
    final protectionKey = '$normalizedName-${item.batchNo}';

    // Add protection for this item
    _recentlyCorrectedItems[protectionKey] = newQuantity;

    // Update local state immediately for UI responsiveness
    _cartItems[index].updateQuantity(newQuantity);
    await _saveUserCarts();
    notifyListeners();

    print('✅ Quantity updated locally - item stays in UI');
    print('🔒 Protected from sync override with key: $protectionKey');

    if (await AuthService.isLoggedIn()) {
      if (isIncrease) {
        print(
            '🔄 Calling _syncQuantityIncreaseWithServer for quantity increase...');
        _syncQuantityIncreaseWithServer(item, newQuantity);
      } else {
        print('🔄 Calling _syncQuantityWithServer for quantity reduction...');
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

      print(
          '🔄 UPDATED _syncQuantityWithServer: Using remove-and-add approach...');

      // For quantity reduction, we need to update the existing cart item
      // Since the server doesn't have a direct "update quantity" API,
      // we'll remove the current item and add the new quantity

      // First, remove the current cart item
      final removeRequestBody = {
        'cart_id': item.id,
      };

      print('=== QUANTITY REDUCTION - REMOVE CURRENT ITEM ===');
      print(
          'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
      print('Request Body: ${jsonEncode(removeRequestBody)}');
      print('Request Headers: Bearer $token');
      print('Item Details:');
      print('  - Cart Item ID: ${item.id}');
      print('  - Name: ${item.name}');
      print('  - Old Quantity: ${item.quantity}');
      print('  - New Quantity: $newQuantity');

      final removeResponse = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(removeRequestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('=== REMOVE RESPONSE ===');
      print('Response Status: ${removeResponse.statusCode}');
      print('Response Body: ${removeResponse.body}');

      if (removeResponse.statusCode == 200 ||
          removeResponse.statusCode == 201) {
        // Now add the new quantity
        final addRequestBody = {
          'productID': int.parse(item.originalProductId ?? item.productId),
          'quantity': newQuantity,
        };

        print('=== QUANTITY REDUCTION - ADD NEW QUANTITY ===');
        print('URL: https://eclcommerce.ernestchemists.com.gh/api/check-auth');
        print('Request Body: ${jsonEncode(addRequestBody)}');
        print('Request Headers: Bearer $token');

        final addResponse = await http
            .post(
              Uri.parse(
                  'https://eclcommerce.ernestchemists.com.gh/api/check-auth'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(addRequestBody),
            )
            .timeout(const Duration(seconds: 10));

        print('=== ADD RESPONSE ===');
        print('Response Status: ${addResponse.statusCode}');
        print('Response Body: ${addResponse.body}');

        if (addResponse.statusCode == 200 || addResponse.statusCode == 201) {
          print('✅ Quantity reduction successful - server updated');

          // Parse the response to get the new cart item ID
          try {
            final responseData = jsonDecode(addResponse.body);
            if (responseData['items'] != null &&
                responseData['items'].isNotEmpty) {
              final newCartItem = responseData['items'][0];
              final newCartId = newCartItem['id'].toString();

              print('🔄 UPDATING LOCAL CART ITEM ID ===');
              print('Old Cart ID: ${item.id}');
              print('New Cart ID: $newCartId');

              // Find and update the local cart item with the new ID
              final itemIndex = _cartItems.indexWhere((cartItem) =>
                  cartItem.name == item.name &&
                  cartItem.batchNo == item.batchNo);

              if (itemIndex != -1) {
                // Create a new cart item with the updated ID
                final updatedCartItem = CartItem(
                  id: newCartId,
                  productId: _cartItems[itemIndex].productId,
                  serverProductId: _cartItems[itemIndex].serverProductId,
                  originalProductId: _cartItems[itemIndex].originalProductId,
                  name: _cartItems[itemIndex].name,
                  price: _cartItems[itemIndex].price,
                  originalPrice: _cartItems[itemIndex].originalPrice,
                  quantity: _cartItems[itemIndex].quantity,
                  image: _cartItems[itemIndex].image,
                  batchNo: _cartItems[itemIndex].batchNo,
                  purchaseDate: _cartItems[itemIndex].purchaseDate,
                  lastModified: _cartItems[itemIndex].lastModified,
                  urlName: _cartItems[itemIndex].urlName,
                  totalPrice: _cartItems[itemIndex].totalPrice,
                );

                // Replace the old item with the new one
                _cartItems[itemIndex] = updatedCartItem;
                print('✅ Updated local cart item ID to: $newCartId');
                await _saveUserCarts();
                notifyListeners();
              } else {
                print('⚠️ Could not find local cart item to update ID');
              }
            }
          } catch (e) {
            print('⚠️ Could not parse response to update cart ID: $e');
          }

          // Sync with server to get updated cart
          await syncWithApi();
        } else {
          print('⚠️ Quantity reduction failed: ${addResponse.statusCode}');
          // Still sync to get current server state
          await syncWithApi();
        }
      } else if (removeResponse.statusCode == 500) {
        print(
            '⚠️ Cart item not found on server, syncing to get current state...');
        // If the cart item doesn't exist on server, sync to get current state
        await syncWithApi();
      } else {
        print('⚠️ Failed to remove current item: ${removeResponse.statusCode}');
        // Still sync to get current server state
        await syncWithApi();
      }
    } catch (e) {
      debugPrint('Quantity reduction error: $e');
      print('⚠️ Quantity reduction failed - local changes preserved');
    }
  }

  // Background sync method for quantity increases
  Future<void> _syncQuantityIncreaseWithServer(
      CartItem item, int newQuantity) async {
    try {
      print(
          '🔄 UPDATED _syncQuantityIncreaseWithServer: Updating existing cart item...');

      // For quantity increases, we need to update the existing cart item
      // Since the server doesn't have a direct "update quantity" API,
      // we'll remove the current item and add the new quantity
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot sync quantity increase - missing auth token');
        return;
      }

      // First, remove the current cart item
      final removeRequestBody = {
        'cart_id': item.id,
      };

      print('=== QUANTITY INCREASE - REMOVE CURRENT ITEM ===');
      print(
          'URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
      print('Request Body: ${jsonEncode(removeRequestBody)}');
      print('Request Headers: Bearer $token');

      final removeResponse = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(removeRequestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('=== REMOVE RESPONSE ===');
      print('Response Status: ${removeResponse.statusCode}');
      print('Response Body: ${removeResponse.body}');

      if (removeResponse.statusCode == 200 ||
          removeResponse.statusCode == 201) {
        // Now add the new quantity
        final addRequestBody = {
          'productID': int.parse(item.originalProductId ?? item.productId),
          'quantity': newQuantity,
        };

        print('=== QUANTITY INCREASE - ADD NEW QUANTITY ===');
        print('URL: https://eclcommerce.ernestchemists.com.gh/api/check-auth');
        print('Request Body: ${jsonEncode(addRequestBody)}');
        print('Request Headers: Bearer $token');

        final addResponse = await http
            .post(
              Uri.parse(
                  'https://eclcommerce.ernestchemists.com.gh/api/check-auth'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(addRequestBody),
            )
            .timeout(const Duration(seconds: 10));

        print('=== ADD RESPONSE ===');
        print('Response Status: ${addResponse.statusCode}');
        print('Response Body: ${addResponse.body}');

        if (addResponse.statusCode == 200 || addResponse.statusCode == 201) {
          print('✅ Quantity increase successful - server updated');

          // Parse the response to get the new cart item ID
          try {
            final responseData = jsonDecode(addResponse.body);
            if (responseData['items'] != null &&
                responseData['items'].isNotEmpty) {
              final newCartItem = responseData['items'][0];
              final newCartId = newCartItem['id'].toString();

              print('🔄 UPDATING LOCAL CART ITEM ID ===');
              print('Old Cart ID: ${item.id}');
              print('New Cart ID: $newCartId');

              // Find and update the local cart item with the new ID
              final itemIndex = _cartItems.indexWhere((cartItem) =>
                  cartItem.name == item.name &&
                  cartItem.batchNo == item.batchNo);

              if (itemIndex != -1) {
                // Create a new cart item with the updated ID
                final updatedCartItem = CartItem(
                  id: newCartId,
                  productId: _cartItems[itemIndex].productId,
                  serverProductId: _cartItems[itemIndex].serverProductId,
                  originalProductId: _cartItems[itemIndex].originalProductId,
                  name: _cartItems[itemIndex].name,
                  price: _cartItems[itemIndex].price,
                  originalPrice: _cartItems[itemIndex].originalPrice,
                  quantity: _cartItems[itemIndex].quantity,
                  image: _cartItems[itemIndex].image,
                  batchNo: _cartItems[itemIndex].batchNo,
                  purchaseDate: _cartItems[itemIndex].purchaseDate,
                  lastModified: _cartItems[itemIndex].lastModified,
                  urlName: _cartItems[itemIndex].urlName,
                  totalPrice: _cartItems[itemIndex].totalPrice,
                );

                // Replace the old item with the new one
                _cartItems[itemIndex] = updatedCartItem;
                print('✅ Updated local cart item ID to: $newCartId');
                await _saveUserCarts();
                notifyListeners();
              } else {
                print('⚠️ Could not find local cart item to update ID');
              }
            }
          } catch (e) {
            print('⚠️ Could not parse response to update cart ID: $e');
          }

          // Sync with server to get updated cart
          await syncWithApi();
        } else {
          print('⚠️ Quantity increase failed: ${addResponse.statusCode}');
          // Still sync to get current server state
          await syncWithApi();
        }
      } else if (removeResponse.statusCode == 500) {
        print(
            '⚠️ Cart item not found on server, syncing to get current state...');
        // If the cart item doesn't exist on server, sync to get current state
        await syncWithApi();
      } else {
        print('⚠️ Failed to remove current item: ${removeResponse.statusCode}');
        // Still sync to get current server state
        await syncWithApi();
      }
    } catch (e) {
      debugPrint('Quantity increase error: $e');
      print('⚠️ Quantity increase failed - local changes preserved');
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

    _userCarts[userId] = merged.values.toList();
    _cartItems = _userCarts[userId]!;
    _userCarts.remove('guest_id');

    // Protect all merged items from sync override
    for (final item in _cartItems) {
      final normalizedName = _normalizeProductName(item.name);
      final protectionKey = '$normalizedName-${item.batchNo}';
      _recentlyCorrectedItems[protectionKey] = item.quantity;
      print('🔒 PROTECTED MERGED ITEM ===');
      print('Product: ${item.name}');
      print('Quantity: ${item.quantity}');
      print('Protection Key: $protectionKey');
      print('===========================');
    }

    await _saveUserCarts();
    notifyListeners();
    // After merging, push each item to the server
    for (final item in _cartItems) {
      await _syncAddToServer(item);
    }
  }
}
