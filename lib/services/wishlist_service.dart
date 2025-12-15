// services/wishlist_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wishlist_item.dart';
import '../models/product.dart';
import '../pages/cart_item.dart';
import '../pages/cartprovider.dart';
import 'package:flutter/material.dart';

class WishlistService {
  static const String _wishlistKey = 'wishlist_items';
  static WishlistService? _instance;
  static WishlistService get instance => _instance ??= WishlistService._();

  WishlistService._();

  Future<List<WishlistItem>> getWishlistItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? wishlistJson = prefs.getString(_wishlistKey);

      if (wishlistJson == null || wishlistJson.isEmpty) {
        return [];
      }

      final List<dynamic> wishlistData = json.decode(wishlistJson);
      return wishlistData.map((item) => WishlistItem.fromJson(item)).toList();
    } catch (e) {
      print('Error getting wishlist items: $e');
      return [];
    }
  }

  // add a product to the wishlist
  Future<bool> addToWishlist(Product product) async {
    try {
      final wishlistItems = await getWishlistItems();

      // check if its already in the wishlist
      if (wishlistItems.any((item) => item.product.id == product.id)) {
        return false; // already there
      }

      final newItem = WishlistItem(
        id: DateTime.now().millisecondsSinceEpoch,
        product: product,
        addedAt: DateTime.now(),
      );

      wishlistItems.add(newItem);
      await _saveWishlistItems(wishlistItems);
      return true;
    } catch (e) {
      print('Error adding to wishlist: $e');
      return false;
    }
  }

  // remove a product from the wishlist
  Future<bool> removeFromWishlist(int productId) async {
    try {
      final wishlistItems = await getWishlistItems();
      wishlistItems.removeWhere((item) => item.product.id == productId);
      await _saveWishlistItems(wishlistItems);
      return true;
    } catch (e) {
      print('Error removing from wishlist: $e');
      return false;
    }
  }

  // check if a product is in the wishlist
  Future<bool> isInWishlist(int productId) async {
    try {
      final wishlistItems = await getWishlistItems();
      return wishlistItems.any((item) => item.product.id == productId);
    } catch (e) {
      print('Error checking wishlist status: $e');
      return false;
    }
  }

  // delete everything from the wishlist
  Future<bool> clearWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_wishlistKey);
      return true;
    } catch (e) {
      print('Error clearing wishlist: $e');
      return false;
    }
  }

  // how many items are in the wishlist
  Future<int> getWishlistCount() async {
    try {
      final wishlistItems = await getWishlistItems();
      return wishlistItems.length;
    } catch (e) {
      print('Error getting wishlist count: $e');
      return 0;
    }
  }

  // save wishlist items to local storage
  Future<void> _saveWishlistItems(List<WishlistItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String wishlistJson =
        json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_wishlistKey, wishlistJson);
  }

  // Move item to cart (remove from wishlist and add to cart)
  Future<bool> moveToCart(int productId) async {
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
        batchNo: itemToMove.product.batchNo ?? '',
        urlName: itemToMove.product.urlName ?? '',
        totalPrice: double.tryParse(itemToMove.product.price) ?? 0.0,
      );

      // get the cart provider and add it to cart
      final cartProvider = CartProvider();
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
