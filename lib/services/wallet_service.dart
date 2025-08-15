// services/wallet_service.dart
// services/wallet_service.dart
// services/wallet_service.dart
// services/wallet_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../pages/auth_service.dart';

class WalletService {
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';
  static const String _walletEndpoint = '/wallet';
  static const String _transactionsEndpoint = '/wallet/transactions';
  static const String _topUpEndpoint = '/wallet/top-up';
  static const String _withdrawEndpoint = '/wallet/withdraw';
  static const String _transferEndpoint = '/wallet/transfer';

  // Cache keys
  static const String _walletCacheKey = 'wallet_cache';
  static const String _transactionsCacheKey = 'transactions_cache';
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Get wallet information for the current user
  static Future<Wallet?> getWallet() async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      // Check cache first
      final cachedWallet = await _getCachedWallet();
      if (cachedWallet != null) {
        return cachedWallet;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$_walletEndpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final wallet = Wallet.fromJson(data['data']);
          await _cacheWallet(wallet);
          return wallet;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch wallet');
        }
      } else if (response.statusCode == 404) {
        // Wallet doesn't exist, create one
        return await createWallet();
      } else {
        throw Exception('Failed to fetch wallet: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching wallet: $e', name: 'WalletService');
      rethrow;
    }
  }

  // Create a new wallet for the current user
  static Future<Wallet> createWallet() async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_walletEndpoint'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'currency': 'GHS',
              'initial_balance': 0.0,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final wallet = Wallet.fromJson(data['data']);
          await _cacheWallet(wallet);
          return wallet;
        } else {
          throw Exception(data['message'] ?? 'Failed to create wallet');
        }
      } else {
        throw Exception('Failed to create wallet: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error creating wallet: $e', name: 'WalletService');
      rethrow;
    }
  }

  // Get wallet transactions
  static Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      // Check cache first
      final cachedTransactions = await _getCachedTransactions();
      if (cachedTransactions.isNotEmpty && page == 1) {
        return cachedTransactions;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$_transactionsEndpoint?page=$page&limit=$limit'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final transactions = (data['data'] as List)
              .map((t) => WalletTransaction.fromJson(t))
              .toList();

          if (page == 1) {
            await _cacheTransactions(transactions);
          }

          return transactions;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch transactions');
        }
      } else {
        throw Exception('Failed to fetch transactions: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching transactions: $e', name: 'WalletService');
      rethrow;
    }
  }

  // Top up wallet
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
          // Clear cache to force refresh
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

  // Process refund to wallet
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
          // Clear cache to force refresh
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

  // Process cashback to wallet
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

      // Check if order amount qualifies for cashback (must be over ₵500)
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
          // Clear cache to force refresh
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

  // Auto-process cashback for qualifying orders (MOCK VERSION - No Backend Required)
  static Future<Map<String, dynamic>> autoProcessCashback({
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      developer.log(
          'Starting MOCK cashback process for order: $orderId, amount: ₵$orderAmount',
          name: 'WalletService');

      // Only process cashback for orders over ₵500
      if (orderAmount < 500) {
        developer.log(
            'Order amount ₵$orderAmount is below ₵500 threshold - no cashback',
            name: 'WalletService');
        return {
          'success': false,
          'message': 'Order must be over ₵500 to qualify for cashback',
          'cashback_amount': 0.0,
          'qualifies': false,
        };
      }

      // Calculate cashback amount (5% of order amount)
      final cashbackAmount = orderAmount * 0.05;
      developer.log('Calculated cashback amount: ₵$cashbackAmount',
          name: 'WalletService');

      // MOCK: Simulate successful cashback processing
      developer.log('MOCK: Simulating successful cashback processing...',
          name: 'WalletService');

      // Simulate a small delay to make it feel real
      await Future.delayed(const Duration(milliseconds: 500));

      developer.log('MOCK: Cashback processed successfully!',
          name: 'WalletService');

      return {
        'success': true,
        'message':
            'MOCK: Cashback of ₵${cashbackAmount.toStringAsFixed(2)} added to wallet',
        'cashback_amount': cashbackAmount,
        'qualifies': true,
        'is_mock': true, // Flag to indicate this is mock data
      };
    } catch (e) {
      developer.log('Error in MOCK cashback process: $e',
          name: 'WalletService');
      return {
        'success': false,
        'message': 'MOCK: Failed to process cashback: ${e.toString()}',
        'cashback_amount': 0.0,
        'qualifies': false,
        'is_mock': true,
      };
    }
  }

  // Use wallet balance for payment
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
          // Clear cache to force refresh
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

  // Cache management
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

  // Check if user has sufficient balance
  static Future<bool> hasSufficientBalance(double amount) async {
    try {
      final wallet = await getWallet();
      return wallet != null && wallet.balance >= amount;
    } catch (e) {
      return false;
    }
  }

  // Get formatted balance string
  static String formatBalance(double balance) {
    return '₵${balance.toStringAsFixed(2)}';
  }

  // Get transaction type display text
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

  // Get transaction status color
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

  // Get transaction type color
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
