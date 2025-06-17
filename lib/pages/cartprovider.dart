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
      _cartItems = [];
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

      print('\n=== Syncing Cart ===');
      print('Request details:');
      print(
          '- URL: https://eclcommerce.ernestchemists.com.gh/api/check-out/$hashedLink');
      print('- Method: GET');
      print('- Headers:');
      print('  Authorization: Bearer ${token.substring(0, 20)}...');
      print('  Accept: application/json');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-out/$hashedLink'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('\nResponse details:');
      print('- Status code: ${response.statusCode}');
      print('- Headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
      print('- Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['cart_items'] != null) {
          print('\nSuccessfully synced cart');
          final items = (data['cart_items'] as List)
              .map((item) => CartItem.fromServerJson(item))
              .toList();
          _cartItems = items;
          await _saveUserCarts();
          notifyListeners();
          print('Cart synced successfully. Items count: ${items.length}');
        } else {
          print('\nFailed to sync cart: No cart items in response');
        }
      } else {
        print('\nFailed to sync cart. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('\nError syncing cart: $e');
    }
  }

  Future<bool> _verifyProductExists(String urlName, String batchNo) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      print('\n=== Verifying Product ===');
      print('Checking product:');
      print('- URL Name: $urlName');
      print('- Batch No: $batchNo');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/product-details/$urlName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('\nVerification response:');
      print('- Status code: ${response.statusCode}');
      print('- Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final productData = data['data']['product'] ?? {};
          final inventoryData = data['data']['inventory'] ?? {};

          // Check if product exists and batch number matches
          final productBatchNo =
              inventoryData['batch_no'] ?? productData['batch_no'];
          final exists = productData != null && productBatchNo == batchNo;

          print(
              'Product verification result: ${exists ? 'Found' : 'Not found'}');
          print('Product data:');
          print('- Product ID: ${productData['id']}');
          print('- Name: ${productData['name']}');
          print('- Batch No: $productBatchNo');
          return exists;
        }
      }
      print('Product verification failed: ${response.body}');
      return false;
    } catch (e) {
      print('Error verifying product: $e');
      return false;
    }
  }

  void addToCart(CartItem item) async {
    if (!await AuthService.isLoggedIn()) {
      debugPrint('User must be logged in to add items to cart');
      return;
    }

    _currentUserId ??= await AuthService.getCurrentUserID();

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Cannot add to cart - missing auth token');
      }

      print('\n=== Adding to Cart ===');
      print('Product details:');
      print('- Item ID: ${item.id}');
      print('- Product ID: ${item.productId}');
      print('- Name: ${item.name}');
      print('- Quantity: ${item.quantity}');
      print('- Batch No: ${item.batchNo}');
      print('- Price: ${item.price}');

      final requestBody = {
        'productID': int.parse(item.productId),
        'quantity': item.quantity,
        'batch_no': item.batchNo,
      };

      final url = 'https://eclcommerce.ernestchemists.com.gh/api/check-auth';

      print('\nRequest details:');
      print('- URL: $url');
      print('- Method: POST');
      print('- Headers:');
      print('  Authorization: Bearer ${token.substring(0, 20)}...');
      print('  Accept: application/json');
      print('  Content-Type: application/json');
      print('- Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('\nResponse details:');
      print('- Status code: ${response.statusCode}');
      print('- Headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
      print('- Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _cartItems.add(item);
          notifyListeners();
        } else {
          throw Exception(data['message'] ?? 'Failed to add item to cart');
        }
      } else {
        throw Exception('Failed to add item to cart: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding item to cart: $e');
      rethrow;
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
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('Cannot remove from cart - missing auth token');
        return;
      }

      print('\n=== Removing from Cart ===');
      print('Request details:');
      print(
          '- URL: https://eclcommerce.ernestchemists.com.gh/api/remove-from-cart');
      print('- Method: POST');
      print('- Headers:');
      print('  Authorization: Bearer ${token.substring(0, 20)}...');
      print('  Accept: application/json');
      print('  Content-Type: application/json');
      print('- Body: ${jsonEncode({'cart_id': cartId})}');

      // Remove from local cart first
      _cartItems.removeWhere((item) => item.id == cartId);
      await _saveUserCarts();
      notifyListeners();

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

      print('\nResponse details:');
      print('- Status code: ${response.statusCode}');
      print('- Headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
      print('- Body: ${response.body}');

      // Always sync with server after removal
      await syncWithApi();
    } catch (e) {
      print('\nError removing from cart: $e');
      // Even if there's an error, try to sync with server
      await syncWithApi();
    }
  }

  void updateQuantity(int index, int newQuantity) async {
    if (_currentUserId == null) return;

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

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  Future<void> _pushCartToServer() async {
    if (_currentUserId == null) return;
    final items = _cartItems.map((item) => item.toJson()).toList();
    await AuthService.updateServerCart(items);
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
