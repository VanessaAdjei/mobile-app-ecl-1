// services/wishlist_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wishlist_item.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class WishlistService {
  static const String _wishlistKey = 'wishlist_items';
  static WishlistService? _instance;
  static WishlistService get instance => _instance ??= WishlistService._();

  WishlistService._();

  // Prevent multiple simultaneous API calls
  Future<List<WishlistItem>>? _pendingRequest;

  Future<List<WishlistItem>> getWishlistItems({bool useCache = true}) async {
    // If there's already a pending request, wait for it instead of making a new one
    if (_pendingRequest != null) {
      debugPrint('⏳ WishlistService: Waiting for pending request...');
      try {
        return await _pendingRequest!;
      } catch (e) {
        debugPrint('❌ WishlistService: Pending request failed: $e');
        // Clear the pending request so we can retry
        _pendingRequest = null;
        // Return empty list on error
        return [];
      }
    }

    // Create new request
    _pendingRequest = _fetchWishlistItems(useCache: useCache);

    try {
      final result = await _pendingRequest!;
      return result;
    } catch (e) {
      debugPrint('❌ WishlistService: Request failed: $e');
      // Return empty list on error instead of rethrowing
      return [];
    } finally {
      // Clear pending request when done
      _pendingRequest = null;
    }
  }

  Future<List<WishlistItem>> _fetchWishlistItems({bool useCache = true}) async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in. Cannot fetch wishlist.');
        return [];
      }

      // Try to fetch from API first
      try {
        debugPrint('=== GET WISHLIST API REQUEST ===');
        debugPrint('Endpoint: ${ApiConfig.getWishlist}');
        debugPrint('Use Cache: $useCache');

        final response = await ApiService.get(
          ApiConfig.getWishlist,
          useCache: useCache,
        );

        debugPrint('=== GET WISHLIST API RESPONSE ===');
        debugPrint('Response Type: ${response.runtimeType}');
        debugPrint('Response Data: $response');
        debugPrint('===================================');

        // Handle different response formats
        List<dynamic> wishlistData = [];
        if (response is Map<String, dynamic>) {
          if (response.containsKey('data')) {
            wishlistData = response['data'] is List
                ? response['data']
                : [response['data']];
          } else if (response.containsKey('wishlist')) {
            wishlistData = response['wishlist'] is List
                ? response['wishlist']
                : [response['wishlist']];
          } else {
            wishlistData = response.values.first is List
                ? response.values.first
                : [response];
            debugPrint(
                'Using first value from response. Items count: ${wishlistData.length}');
          }
        } else if (response is List) {
          wishlistData = response;
          debugPrint('Response is a List. Items count: ${wishlistData.length}');
        }

        debugPrint('Found ${wishlistData.length} wishlist items in response');

        // Parse items with error handling for each item
        final List<WishlistItem> items = [];
        for (int i = 0; i < wishlistData.length; i++) {
          try {
            final itemData = wishlistData[i];
            debugPrint(
                'Parsing wishlist item $i: ${itemData is Map ? itemData['id'] : 'unknown format'}');
            final wishlistItem =
                WishlistItem.fromJson(itemData as Map<String, dynamic>);
            items.add(wishlistItem);
            debugPrint(
                'Successfully parsed item $i: ID=${wishlistItem.id}, Product ID=${wishlistItem.product.id}');
          } catch (e) {
            debugPrint('❌ Error parsing wishlist item $i: $e');
            debugPrint('❌ Item data: ${wishlistData[i]}');
            // Skip this item and continue with others
            continue;
          }
        }

        // Filter out local-only items (timestamp IDs > 1 billion)
        // Only keep real API items
        final apiItems = items.where((item) => item.id <= 1000000000).toList();
        debugPrint('Successfully parsed ${items.length} wishlist items');
        debugPrint(
            'Filtered to ${apiItems.length} real API items (removed ${items.length - apiItems.length} local-only items)');

        // Cache only API items locally (with error handling)
        try {
          await _saveWishlistItems(apiItems);
        } catch (cacheError) {
          debugPrint('⚠️ Error caching wishlist items: $cacheError');
          // Continue even if caching fails
        }

        debugPrint(
            '✅ Successfully returning ${apiItems.length} wishlist items');
        return apiItems;
      } catch (apiError) {
        debugPrint('=== GET WISHLIST API ERROR ===');
        debugPrint('Error Type: ${apiError.runtimeType}');
        debugPrint('Error Message: $apiError');
        debugPrint('Stack trace: ${StackTrace.current}');

        // Check if this is a connectivity error (offline) vs other API errors
        final errorString = apiError.toString();
        final isConnectivityError = errorString.contains('Connection failed') ||
            errorString.contains('No internet connection') ||
            errorString.contains('Unable to connect') ||
            errorString.contains('Request timeout');

        if (isConnectivityError) {
          debugPrint('Connectivity error detected - will use cached products');
          debugPrint('================================');
          // Only use cached items when offline (connectivity error)
          debugPrint(
              'Attempting to load cached API items from local storage...');
          try {
            final prefs = await SharedPreferences.getInstance();
            final String? wishlistJson = prefs.getString(_wishlistKey);

            if (wishlistJson != null && wishlistJson.isNotEmpty) {
              final List<dynamic> wishlistData = json.decode(wishlistJson);
              final cachedItems = wishlistData
                  .map((item) => WishlistItem.fromJson(item))
                  .toList();

              // Filter out local-only items (timestamp IDs > 1 billion)
              // Only return real API items that were previously fetched from server
              final apiItems =
                  cachedItems.where((item) => item.id <= 1000000000).toList();

              debugPrint(
                  'Loaded ${apiItems.length} cached API items from local storage');
              return apiItems;
            }
          } catch (e) {
            debugPrint('Error loading cached items: $e');
          }

          // Return empty list if no cached API items available
          debugPrint('No cached API items available');
          return [];
        } else {
          // Other API errors (auth, server errors, etc.) - don't use cache, use server products only
          debugPrint('API error (not connectivity) - not using cache');
          debugPrint('Error details: $apiError');
          debugPrint('================================');
          return [];
        }
      }
    } catch (e) {
      debugPrint('Error getting wishlist items: $e');
      return [];
    }
  }

  // add a product to the wishlist
  Future<bool> addToWishlist(Product product) async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in. Cannot add to wishlist.');
        throw Exception('Please sign in to add items to your wishlist');
      }

      // Check if already in wishlist locally first (quick check)
      final wishlistItems = await getWishlistItems(useCache: true);
      if (wishlistItems.any((item) => item.product.id == product.id)) {
        return false; // already there
      }

      // Call API to add to wishlist
      try {
        debugPrint('=== ADD TO WISHLIST API REQUEST ===');
        debugPrint('Endpoint: ${ApiConfig.addToWishlist}');
        debugPrint('Request Body: {"product_id": ${product.id}}');
        debugPrint('Product: ${product.name} (ID: ${product.id})');

        final response = await ApiService.post(
          ApiConfig.addToWishlist,
          body: {
            'product_id': product.id,
          },
        );

        debugPrint('=== ADD TO WISHLIST API RESPONSE ===');
        debugPrint('Response Type: ${response.runtimeType}');
        debugPrint('Response Data: $response');
        debugPrint('====================================');

        // Handle the API response format:
        // {
        //   "success": true,
        //   "message": "Product added to wishlist",
        //   "data": {
        //     "user_id": 121,
        //     "product_id": 77,
        //     "updated_at": "2026-01-14T12:02:08.000000Z",
        //     "created_at": "2026-01-14T12:02:08.000000Z",
        //     "id": 1
        //   }
        // }
        if (response is Map<String, dynamic>) {
          final success = response['success'] ?? false;
          final message = response['message'] ?? 'No message';
          debugPrint('Success: $success');
          debugPrint('Message: $message');

          if (success && response.containsKey('data')) {
            final data = response['data'] as Map<String, dynamic>;
            final wishlistItemId = data['id'] as int?;
            final productId = data['product_id'] as int?;
            final userId = data['user_id'] as int?;
            final createdAt = data['created_at'] as String?;
            final updatedAt = data['updated_at'] as String?;

            debugPrint('Wishlist Item ID: $wishlistItemId');
            debugPrint('Product ID: $productId');
            debugPrint('User ID: $userId');
            debugPrint('Created At: $createdAt');
            debugPrint('Updated At: $updatedAt');
            debugPrint('Successfully added to wishlist!');

            // Refresh wishlist from API after adding to get the complete item with product details
            try {
              await getWishlistItems(useCache: false);
            } catch (refreshError) {
              debugPrint(
                  'Failed to refresh wishlist after adding: $refreshError');
              // Still return true since the add was successful
            }
            return true;
          } else {
            debugPrint('API returned success=false or missing data');
            debugPrint('Response keys: ${response.keys.toList()}');
            return false;
          }
        } else {
          debugPrint(
              'Unexpected response format. Type: ${response.runtimeType}');
          // If response format is unexpected, try to refresh but don't fail if it errors
          try {
            await getWishlistItems(useCache: false);
          } catch (refreshError) {
            debugPrint('Failed to refresh wishlist: $refreshError');
          }
          return true;
        }
      } catch (apiError) {
        debugPrint('=== ADD TO WISHLIST API ERROR ===');
        debugPrint('Error Type: ${apiError.runtimeType}');
        debugPrint('Error Message: $apiError');
        debugPrint(
            'No API response received - connection failed before response');
        debugPrint('===================================');
        // Don't save locally - only use real API items
        // Don't try to refresh wishlist if add failed
        return false;
      }
    } catch (e) {
      debugPrint('Error adding to wishlist: $e');
      return false;
    }
  }

  // remove a product from the wishlist by product ID (finds wishlist item ID first)
  Future<bool> removeFromWishlist(int productId) async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in. Cannot remove from wishlist.');
        throw Exception('Please sign in to remove items from your wishlist');
      }

      // Get current wishlist to find the wishlist item ID
      // Always use fresh data (no cache) to ensure we have the latest state
      final wishlistItems = await getWishlistItems(useCache: false);
      debugPrint(
          '🔍 removeFromWishlist: Looking for product ID $productId in ${wishlistItems.length} items');
      debugPrint(
          '🔍 removeFromWishlist: Current items: ${wishlistItems.map((item) => item.product.id).toList()}');

      final itemToRemove = wishlistItems.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => WishlistItem(
          id: 0,
          product: Product(
            id: 0,
            name: '',
            description: '',
            urlName: '',
            status: '',
            batchNo: '',
            price: '0',
            thumbnail: '',
            quantity: '0',
            category: '',
            route: '',
          ),
          addedAt: DateTime.now(),
        ),
      );

      if (itemToRemove.id == 0) {
        debugPrint(
            '⚠️ removeFromWishlist: Product ID $productId not found in wishlist');
        debugPrint(
            '⚠️ removeFromWishlist: Available product IDs: ${wishlistItems.map((item) => item.product.id).toList()}');
        return false; // Item not found
      }

      debugPrint(
          '✅ removeFromWishlist: Found item to remove - Wishlist Item ID: ${itemToRemove.id}, Product ID: ${itemToRemove.product.id}');

      // Only work with real API items (not local-only timestamp IDs)
      // Timestamp IDs are typically > 1 billion (milliseconds since epoch)
      // Real API IDs are usually small integers
      final isLocalOnlyItem =
          itemToRemove.id > 1000000000; // Timestamp threshold

      if (isLocalOnlyItem) {
        debugPrint('Item has local-only timestamp ID: ${itemToRemove.id}');
        debugPrint('Skipping removal - only API items are supported');
        // Remove from local cache if it exists
        wishlistItems.removeWhere((item) => item.product.id == productId);
        await _saveWishlistItems(wishlistItems);
        return false; // Return false since it wasn't a real API item
      }

      // Call API to remove from wishlist using wishlist item ID
      try {
        final endpoint = '${ApiConfig.removeFromWishlist}/${itemToRemove.id}';
        debugPrint('=== REMOVE FROM WISHLIST API REQUEST ===');
        debugPrint('Endpoint: $endpoint');
        debugPrint('Wishlist Item ID: ${itemToRemove.id}');
        debugPrint('Product ID: $productId');

        final response = await ApiService.delete(endpoint);

        debugPrint('=== REMOVE FROM WISHLIST API RESPONSE ===');
        debugPrint('Response Type: ${response.runtimeType}');
        debugPrint('Response Data: $response');
        debugPrint('==========================================');

        // Handle the API response format (similar to add):
        // {
        //   "success": true,
        //   "message": "Product removed from wishlist",
        //   "data": { ... } // optional
        // }
        if (response is Map<String, dynamic>) {
          final success = response['success'] ?? false;
          final message = response['message'] ?? 'No message';
          debugPrint('Success: $success');
          debugPrint('Message: $message');

          if (success) {
            debugPrint(
                'Successfully removed from wishlist. Item ID: ${itemToRemove.id}, Product ID: $productId');
            if (response.containsKey('data')) {
              debugPrint('Response data: ${response['data']}');
            }
            // Refresh wishlist from API after removing
            await getWishlistItems(useCache: false);
            return true;
          } else {
            debugPrint('API returned success=false');
            debugPrint('Response keys: ${response.keys.toList()}');
            return false;
          }
        } else {
          debugPrint(
              'Unexpected response format. Type: ${response.runtimeType}');
          // If response format is unexpected, still refresh and return true
          await getWishlistItems(useCache: false);
          return true;
        }
      } catch (apiError) {
        debugPrint('API error removing from wishlist: $apiError');
        // Don't remove locally - only work with API items
        // Remove from local cache if it exists
        wishlistItems.removeWhere((item) => item.product.id == productId);
        await _saveWishlistItems(wishlistItems);
        return false; // Return false since API call failed
      }
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
      return false;
    }
  }

  // remove a wishlist item by wishlist item ID (direct API call)
  Future<bool> removeWishlistItemById(int wishlistItemId) async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in. Cannot remove wishlist item.');
        throw Exception('Please sign in to remove items from your wishlist');
      }

      // Only work with real API items (not local-only timestamp IDs)
      final isLocalOnlyItem =
          wishlistItemId > 1000000000; // Timestamp threshold

      if (isLocalOnlyItem) {
        debugPrint('Item has local-only timestamp ID: $wishlistItemId');
        debugPrint('Skipping removal - only API items are supported');
        // Remove from local cache if it exists
        final wishlistItems = await getWishlistItems();
        wishlistItems.removeWhere((item) => item.id == wishlistItemId);
        await _saveWishlistItems(wishlistItems);
        return false; // Return false since it wasn't a real API item
      }

      // Call API to remove from wishlist
      try {
        final endpoint = '${ApiConfig.removeFromWishlist}/$wishlistItemId';
        debugPrint('=== REMOVE WISHLIST ITEM BY ID API REQUEST ===');
        debugPrint('Endpoint: $endpoint');
        debugPrint('Wishlist Item ID: $wishlistItemId');

        final response = await ApiService.delete(endpoint);

        debugPrint('=== REMOVE WISHLIST ITEM BY ID API RESPONSE ===');
        debugPrint('Response Type: ${response.runtimeType}');
        debugPrint('Response Data: $response');
        debugPrint('===============================================');

        // Handle the API response format:
        // {
        //   "success": true,
        //   "message": "Product removed from wishlist",
        //   "data": { ... } // optional
        // }
        if (response is Map<String, dynamic>) {
          final success = response['success'] ?? false;
          final message = response['message'] ?? 'No message';
          debugPrint('Success: $success');
          debugPrint('Message: $message');

          if (success) {
            debugPrint(
                'Successfully removed wishlist item. Item ID: $wishlistItemId');
            if (response.containsKey('data')) {
              debugPrint('Response data: ${response['data']}');
            }
            // Refresh wishlist from API after removing
            await getWishlistItems(useCache: false);
            return true;
          } else {
            debugPrint('API returned success=false');
            debugPrint('Response keys: ${response.keys.toList()}');
            return false;
          }
        } else {
          debugPrint(
              'Unexpected response format. Type: ${response.runtimeType}');
          // If response format is unexpected, still refresh and return true
          await getWishlistItems(useCache: false);
          return true;
        }
      } catch (apiError) {
        debugPrint('API error removing wishlist item: $apiError');
        // Don't remove locally - only work with API items
        // Remove from local cache if it exists
        final wishlistItems = await getWishlistItems();
        wishlistItems.removeWhere((item) => item.id == wishlistItemId);
        await _saveWishlistItems(wishlistItems);
        return false; // Return false since API call failed
      }
    } catch (e) {
      debugPrint('Error removing wishlist item: $e');
      return false;
    }
  }

  // check if a product is in the wishlist
  Future<bool> isInWishlist(int productId) async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return false; // Not logged in, so item can't be in wishlist
      }

      final wishlistItems = await getWishlistItems();
      return wishlistItems.any((item) => item.product.id == productId);
    } catch (e) {
      debugPrint('Error checking wishlist status: $e');
      return false;
    }
  }

  // delete everything from the wishlist
  Future<bool> clearWishlist() async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in. Cannot clear wishlist.');
        throw Exception('Please sign in to clear your wishlist');
      }

      // Get all wishlist items and remove them one by one via API
      final wishlistItems = await getWishlistItems();

      bool allRemoved = true;
      for (var item in wishlistItems) {
        final removed = await removeWishlistItemById(item.id);
        if (!removed) {
          allRemoved = false;
        }
      }

      // Also clear local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_wishlistKey);

      return allRemoved;
    } catch (e) {
      debugPrint('Error clearing wishlist: $e');
      return false;
    }
  }

  // how many items are in the wishlist
  Future<int> getWishlistCount({bool useCache = false}) async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return 0; // Not logged in, so count is 0
      }

      // Use fresh data by default to ensure accurate count
      final wishlistItems = await getWishlistItems(useCache: useCache);
      debugPrint(
          '📊 getWishlistCount: Returning count ${wishlistItems.length} (useCache: $useCache)');
      return wishlistItems.length;
    } catch (e) {
      debugPrint('Error getting wishlist count: $e');
      return 0;
    }
  }

  // save wishlist items to local storage
  Future<void> _saveWishlistItems(List<WishlistItem> items) async {
    try {
      debugPrint('💾 Saving ${items.length} wishlist items to cache...');
      final prefs = await SharedPreferences.getInstance();

      // Convert items to JSON with error handling
      final List<Map<String, dynamic>> itemsJson = [];
      for (int i = 0; i < items.length; i++) {
        try {
          final itemJson = items[i].toJson();
          itemsJson.add(itemJson);
        } catch (e) {
          debugPrint('❌ Error converting item $i to JSON: $e');
          debugPrint(
              '❌ Item ID: ${items[i].id}, Product ID: ${items[i].product.id}');
          // Skip this item if it can't be serialized
          continue;
        }
      }

      final String wishlistJson = json.encode(itemsJson);
      await prefs.setString(_wishlistKey, wishlistJson);
      debugPrint(
          '✅ Successfully saved ${itemsJson.length} wishlist items to cache');
    } catch (e) {
      debugPrint('❌ Error saving wishlist items: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      rethrow; // Re-throw so caller knows caching failed
    }
  }

  /// Move item to cart (remove from wishlist and add to cart).
  /// [cartProvider] must be the app's CartProvider from Provider.of - do not
  /// instantiate a new CartProvider.
  Future<bool> moveToCart(int productId, CartProvider cartProvider) async {
    try {
      final wishlistItems = await getWishlistItems();
      final itemToMove = wishlistItems.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => throw Exception('Item not found in wishlist'),
      );

      // turn the wishlist item into a cart item
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: itemToMove.product.id.toString(),
        name: itemToMove.product.name,
        price: double.tryParse(itemToMove.product.price) ?? 0.0,
        quantity: 1, // Default quantity when moving from wishlist
        image: itemToMove.product.thumbnail,
        batchNo: itemToMove.product.batchNo,
        urlName: itemToMove.product.urlName,
        totalPrice: double.tryParse(itemToMove.product.price) ?? 0.0,
      );

      await cartProvider.addToCart(cartItem);

      // remove it from wishlist after we add it to cart
      await removeFromWishlist(productId);

      debugPrint('Successfully moved ${itemToMove.product.name} to cart');
      return true;
    } catch (e) {
      debugPrint('Error moving item to cart: $e');
      return false;
    }
  }
}
