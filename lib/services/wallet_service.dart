// services/wallet_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/wallet.dart';
import 'auth_service.dart';

class WalletService {
  static const String _baseUrl =
      ApiConfig.baseUrl;
  static const String _walletEndpoint = '/wallet';
  static const String _topUpEndpoint = '/wallet/top-up';

  // keys for caching stuff
  static const String _walletCacheKey = 'wallet_cache';
  static const String _transactionsCacheKey = 'transactions_cache';
  static const Duration _cacheDuration = Duration(minutes: 15);

  // get wallet info for the current user (using mock data for now, no api)
  static Future<Wallet?> getWallet() async {
    try {
      final userId = await AuthService.getCurrentUserID();

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // check cache first
      final cachedWallet = await _getCachedWallet();
      if (cachedWallet != null) {
        return cachedWallet;
      }

      // make a fake wallet since theres no api yet
      developer.log('Creating mock wallet for user: $userId',
          name: 'WalletService');
      final mockWallet = _createMockWallet(userId);
      await _cacheWallet(mockWallet);
      return mockWallet;
    } catch (e) {
      developer.log('Error creating mock wallet: $e', name: 'WalletService');
      rethrow;
    }
  }

  // make a fake wallet (no api needed)
  static Wallet _createMockWallet(String userId) {
    return Wallet(
      id: 'mock_wallet_$userId',
      userId: userId,
      balance: 0.0,
      currency: 'GHS',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // make an empty transactions list (no fake data)
  static List<WalletTransaction> _createEmptyTransactions(String userId) {
    return [];
  }

  // make a new wallet for the user (using mock data for now)
  static Future<Wallet> createWallet() async {
    try {
      final userId = await AuthService.getCurrentUserID();

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // make a fake wallet since theres no api
      developer.log('Creating mock wallet for user: $userId',
          name: 'WalletService');
      final mockWallet = _createMockWallet(userId);
      await _cacheWallet(mockWallet);
      return mockWallet;
    } catch (e) {
      developer.log('Error creating mock wallet: $e', name: 'WalletService');
      rethrow;
    }
  }

  static Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final userId = await AuthService.getCurrentUserID();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // check cache first
      final cachedTransactions = await _getCachedTransactions();
      if (cachedTransactions.isNotEmpty && page == 1) {
        return cachedTransactions;
      }

      // return empty list since theres no api
      developer.log('Returning empty transactions for user: $userId',
          name: 'WalletService');
      final emptyTransactions = _createEmptyTransactions(userId);

      if (page == 1) {
        await _cacheTransactions(emptyTransactions);
      }

      return emptyTransactions;
    } catch (e) {
      developer.log('Error getting transactions: $e', name: 'WalletService');
      rethrow;
    }
  }

  // add money to the wallet
  static Future<Map<String, dynamic>> topUpWallet({
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_topUpEndpoint'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'amount': amount,
              'payment_method': paymentMethod,
              'reference':
                  reference ?? 'TOPUP_${DateTime.now().millisecondsSinceEpoch}',
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          // clear cache so it reloads
          await _clearCache();
          return {
            'success': true,
            'message': data['message'] ?? 'Wallet topped up successfully',
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to top up wallet');
        }
      } else {
        throw Exception(data['message'] ??
            'Failed to top up wallet: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error topping up wallet: $e', name: 'WalletService');
      rethrow;
    }
  }

  // add a refund to the wallet
  static Future<Map<String, dynamic>> processRefund({
    required double amount,
    required String orderId,
    required String reason,
    String? description,
  }) async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_walletEndpoint/refund'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'amount': amount,
              'order_id': orderId,
              'reason': reason,
              'description': description ?? 'Refund for order $orderId',
              'type': 'refund',
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          // clear cache so it reloads
          await _clearCache();
          return {
            'success': true,
            'message': data['message'] ?? 'Refund processed successfully',
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to process refund');
        }
      } else {
        throw Exception(data['message'] ??
            'Failed to process refund: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error processing refund: $e', name: 'WalletService');
      rethrow;
    }
  }

  // add cashback to the wallet
  static Future<Map<String, dynamic>> processCashback({
    required double amount,
    required String orderId,
    required String reason,
    String? description,
  }) async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      // check if the order is big enough for cashback (has to be over ₵500)
      if (amount < 500) {
        return {
          'success': false,
          'message': 'Order must be over ₵500 to qualify for cashback',
          'data': null,
        };
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_walletEndpoint/cashback'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'amount': amount,
              'order_id': orderId,
              'reason': reason,
              'description': description ?? 'Cashback for order $orderId',
              'type': 'cashback',
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          // clear cache so it reloads
          await _clearCache();
          return {
            'success': true,
            'message': data['message'] ?? 'Cashback processed successfully',
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to process cashback');
        }
      } else {
        throw Exception(data['message'] ??
            'Failed to process cashback: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error processing cashback: $e', name: 'WalletService');
      rethrow;
    }
  }

  // automatically add cashback for big orders (turned off, no backend)
  static Future<Map<String, dynamic>> autoProcessCashback({
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      developer.log(
          'Cashback processing disabled for order: $orderId, amount: ₵$orderAmount',
          name: 'WalletService');

      // return a message saying its disabled
      return {
        'success': false,
        'message': 'Cashback feature is currently disabled',
        'cashback_amount': 0.0,
        'qualifies': false,
        'is_mock': false,
      };
    } catch (e) {
      developer.log('Error in cashback process: $e', name: 'WalletService');
      return {
        'success': false,
        'message': 'Failed to process cashback: ${e.toString()}',
        'cashback_amount': 0.0,
        'qualifies': false,
        'is_mock': false,
      };
    }
  }

  // use wallet money to pay for something
  static Future<Map<String, dynamic>> useWalletBalance({
    required double amount,
    required String orderId,
    String? description,
  }) async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_walletEndpoint/use'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'amount': amount,
              'order_id': orderId,
              'description': description ?? 'Payment for order $orderId',
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          // clear cache so it reloads
          await _clearCache();
          return {
            'success': true,
            'message': data['message'] ?? 'Wallet payment successful',
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to use wallet balance');
        }
      } else {
        throw Exception(data['message'] ??
            'Failed to use wallet balance: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error using wallet balance: $e', name: 'WalletService');
      rethrow;
    }
  }

  // stuff for managing the cache
  static Future<void> _cacheWallet(Wallet wallet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': wallet.toJson(),
      };
      await prefs.setString(_walletCacheKey, json.encode(cacheData));
    } catch (e) {
      developer.log('Error caching wallet: $e', name: 'WalletService');
    }
  }

  static Future<Wallet?> _getCachedWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_walletCacheKey);
      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return Wallet.fromJson(data['data']);
        }
      }
    } catch (e) {
      developer.log('Error reading cached wallet: $e', name: 'WalletService');
    }
    return null;
  }

  static Future<void> _cacheTransactions(
      List<WalletTransaction> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': transactions.map((t) => t.toJson()).toList(),
      };
      await prefs.setString(_transactionsCacheKey, json.encode(cacheData));
    } catch (e) {
      developer.log('Error caching transactions: $e', name: 'WalletService');
    }
  }

  static Future<List<WalletTransaction>> _getCachedTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_transactionsCacheKey);
      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return (data['data'] as List)
              .map((t) => WalletTransaction.fromJson(t))
              .toList();
        }
      }
    } catch (e) {
      developer.log('Error reading cached transactions: $e',
          name: 'WalletService');
    }
    return [];
  }

  static Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_walletCacheKey);
      await prefs.remove(_transactionsCacheKey);
    } catch (e) {
      developer.log('Error clearing cache: $e', name: 'WalletService');
    }
  }

  // check if they have enough money in the wallet
  static Future<bool> hasSufficientBalance(double amount) async {
    try {
      final wallet = await getWallet();
      return wallet != null && wallet.balance >= amount;
    } catch (e) {
      return false;
    }
  }

  // format the balance to show nicely
  static String formatBalance(double balance) {
    // ios handles unicode better, android sometimes cant show the ghana cedi symbol
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return '₵${balance.toStringAsFixed(2)}'; // Use Ghana Cedi symbol on iOS
    } else {
      return 'GHS ${balance.toStringAsFixed(2)}'; // Use GHS text on Android and other platforms
    }
  }

  // get the text to show for a transaction type
  static String getTransactionTypeText(String type) {
    switch (type) {
      case 'credit':
        return 'Credit';
      case 'debit':
        return 'Debit';
      case 'refund':
        return 'Refund';
      case 'cashback':
        return 'Cashback';
      case 'bonus':
        return 'Bonus';
      case 'return':
        return 'Return';
      default:
        return type.capitalize();
    }
  }

  // get the color for a transaction status
  static int getTransactionStatusColor(String status) {
    switch (status) {
      case 'completed':
        return 0xFF4CAF50; // Green
      case 'pending':
        return 0xFFFF9800; // Orange
      case 'failed':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  // get the color for a transaction type
  static int getTransactionTypeColor(String type) {
    switch (type) {
      case 'refund':
        return 0xFF4CAF50; // Green - Money back
      case 'cashback':
        return 0xFF2196F3; // Blue - Rewards
      case 'bonus':
        return 0xFFFF9800; // Orange - Special offers
      case 'return':
        return 0xFF9C27B0; // Purple - Product returns
      case 'credit':
        return 0xFF4CAF50; // Green - General credit
      case 'debit':
        return 0xFFF44336; // Red - Money spent
      default:
        return 0xFF9E9E9E; // Grey - Unknown
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
