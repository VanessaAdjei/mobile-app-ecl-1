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
          final items = (data['cart_items'] as List)
              .map((item) => CartItem.fromServerJson(item))
              .toList();
          print('=== SYNC CART PROCESSED ITEMS ===');
          print('Number of items synced: ${items.length}');
          print(
              'Items: ${items.map((item) => '${item.name} (${item.quantity})').toList()}');
          print('==================================');
          _cartItems = items;
          await _saveUserCarts();
          notifyListeners();
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
    // Check if item already exists in cart
    final existingItemIndex = _cartItems.indexWhere((cartItem) =>
        cartItem.productId == item.productId &&
        cartItem.batchNo == item.batchNo);

    if (existingItemIndex != -1) {
      // Item already exists, update quantity
      _cartItems[existingItemIndex].updateQuantity(
          _cartItems[existingItemIndex].quantity + item.quantity);
      await _saveUserCarts();
      notifyListeners();
      return;
    }

    // For non-logged-in users, add to local cart only
    if (!await AuthService.isLoggedIn()) {
      _cartItems.add(item);
      await _saveUserCarts();
      notifyListeners();
      return;
    }

    // For logged-in users, try to sync with server
    _currentUserId ??= await AuthService.getCurrentUserID();

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        // Fallback to local cart if no token
        debugPrint(
            'Cannot add to cart - missing auth token, adding to local cart');
        _cartItems.add(item);
        await _saveUserCarts();
        notifyListeners();
        return;
      }

      final requestBody = {
        'productID': int.parse(item.productId),
        'quantity': item.quantity,
      };

      final url = 'https://eclcommerce.ernestchemists.com.gh/api/check-auth';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10)); // Add timeout

      print('=== ADD TO CART API RESPONSE ===');
      print('URL: $url');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('=== PARSED RESPONSE DATA ===');
        print('Status: ${data['status']}');
        print('Added: ${data['added']}');
        print('Items: ${data['items']}');
        print('Data Keys: ${data.keys.toList()}');
        print('===========================');

        if (data['status'] == 'success') {
          // Use the actual cart items returned from the API
          if (data['items'] != null && data['items'] is List) {
            final List<dynamic> itemsData = data['items'];
            _cartItems.clear(); // Clear existing items

            for (final itemData in itemsData) {
              try {
                // Use the fromServerJson factory method which handles API response format
                final cartItem = CartItem.fromServerJson(itemData);
                _cartItems.add(cartItem);
              } catch (e) {
                debugPrint('Error parsing cart item: $e');
                // Fallback to manual parsing if fromServerJson fails
                try {
                  final cartItem = CartItem(
                    id: itemData['id'].toString(),
                    productId: itemData['productID'].toString(),
                    name: itemData['product']['name'] ?? 'Unknown Product',
                    price: (itemData['product']['price'] ?? 0.0).toDouble(),
                    quantity: itemData['quantity'] ?? 1,
                    image: itemData['product']['image'] ?? '',
                    batchNo: itemData['batch_no'] ?? '',
                    urlName: itemData['url_name'] ?? '',
                    totalPrice:
                        ((itemData['product']['price'] ?? 0.0).toDouble() *
                            (itemData['quantity'] ?? 1)),
                  );
                  _cartItems.add(cartItem);
                } catch (fallbackError) {
                  debugPrint('Fallback parsing also failed: $fallbackError');
                }
              }
            }

            await _saveUserCarts();
            notifyListeners();
            print('=== CART UPDATED FROM API ===');
            print('Cart items count: ${_cartItems.length}');
            for (final item in _cartItems) {
              print(
                  'Item: ${item.name} (ID: ${item.productId}, Batch: ${item.batchNo}, Qty: ${item.quantity})');
            }
            print('=============================');
          } else {
            // Fallback to adding the item locally if API doesn't return items
            _cartItems.add(item);
            await _saveUserCarts();
            notifyListeners();
          }
        } else {
          // API returned status other than success, fallback to local cart
          debugPrint('API returned status: ${data['status']}');
          _cartItems.add(item);
          await _saveUserCarts();
          notifyListeners();
        }
      } else {
        // HTTP error, fallback to local cart
        debugPrint('HTTP error ${response.statusCode}, adding to local cart');
        _cartItems.add(item);
        await _saveUserCarts();
        notifyListeners();
      }
    } catch (e) {
      // Any exception, fallback to local cart
      debugPrint('Error adding to cart: $e, adding to local cart');
      _cartItems.add(item);
      await _saveUserCarts();
      notifyListeners();
    }
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

      if (newQuantity > currentQuantity) {
        // Increment: Update local state
        _cartItems[index].updateQuantity(newQuantity);
        await _saveUserCarts();
        notifyListeners();
      } else if (newQuantity < currentQuantity) {
        // Decrement: Update local state
        _cartItems[index].updateQuantity(newQuantity);
        await _saveUserCarts();
        notifyListeners();
      }
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
