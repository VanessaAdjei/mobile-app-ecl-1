// services/wallet_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/wallet.dart';
import 'auth_service.dart';
import 'order_history_transformer.dart';

class WalletService {
  static const String _baseUrl =
      ApiConfig.baseUrl;
  static const String _walletEndpoint = '/wallet';
  static const String _topUpEndpoint = '/wallet/top-up';

  // keys for caching stuff
  static const String _walletCacheKey = 'wallet_cache';
  static const String _transactionsCacheKey = 'transactions_cache';
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Page size for [getTransactions] (keep in sync with [WalletProvider.loadMoreTransactions]).
  static const int transactionsPageSize = 20;

  // get wallet info for the current user — prefer live API, then cache, then mock.
  static Future<Wallet?> getWallet() async {
    try {
      final userId = await AuthService.getCurrentUserID();

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final token = await AuthService.getToken();
      if (token != null) {
        try {
          final response = await http
              .get(
                Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.wallet)),
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(const Duration(seconds: 20));

          if (response.statusCode == 200) {
            final decoded = json.decode(response.body);
            if (decoded is Map<String, dynamic>) {
              final w = _parseWalletFromApiBody(decoded);
              if (w != null) {
                await _cacheWallet(w);
                return w;
              }
            }
          }
        } catch (e) {
          developer.log('Wallet API GET failed: $e', name: 'WalletService');
        }
      }

      final cachedWallet = await _getCachedWallet();
      if (cachedWallet != null) {
        return cachedWallet;
      }

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

  static Wallet? _parseWalletFromApiBody(Map<String, dynamic> body) {
    final d = body['data'];
    if (d is! Map) return null;
    final m = Map<String, dynamic>.from(d);
    try {
      var w = Wallet.fromJson(m);
      if (w.id.isEmpty && m['wallet'] is Map) {
        w = Wallet.fromJson(Map<String, dynamic>.from(m['wallet'] as Map));
      }
      return w.id.isNotEmpty ? w : null;
    } catch (e) {
      developer.log('Wallet JSON parse error: $e', name: 'WalletService');
      return null;
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
    int limit = transactionsPageSize,
  }) async {
    final userId = await AuthService.getCurrentUserID();
    if (userId == null) {
      developer.log('getTransactions: not authenticated', name: 'WalletService');
      return [];
    }

    try {
      // Same API as Your Orders (PurchaseScreen): [AuthService.getOrders] → GET {ApiConfig.baseUrl}/orders (+ local COD merge). No /wallet/transactions.
      final result = Map<String, dynamic>.from(await AuthService.getOrders());
      final ok = result['status'] == 'success' ||
          result['success'] == true ||
          result['success'] == 1;
      final rawList = _extractOrdersListFromGetOrdersResult(result);
      if (ok && rawList != null) {
        List<Map<String, dynamic>> rows;
        try {
          rows = OrderHistoryTransformer.processRawOrders(rawList);
        } catch (e, st) {
          developer.log(
            'processRawOrders failed, using raw order rows: $e',
            name: 'WalletService',
            error: e,
            stackTrace: st,
          );
          rows = _orderRowsFallbackWithoutGrouping(rawList);
        }
        if (rows.isEmpty && rawList.isNotEmpty) {
          developer.log(
            'WalletService: grouping yielded 0 rows from ${rawList.length} raw orders; using ungrouped list.',
            name: 'WalletService',
          );
          rows = _orderRowsFallbackWithoutGrouping(rawList);
        }
        final all = <WalletTransaction>[];
        for (final m in rows) {
          try {
            all.add(_walletTransactionFromOrderRow(m, userId));
          } catch (e, st) {
            developer.log(
              'WalletService: skip row when mapping to transaction: $e',
              name: 'WalletService',
              error: e,
              stackTrace: st,
            );
          }
        }
        final start = (page - 1) * limit;
        if (start >= all.length) {
          return [];
        }
        final end = (start + limit) > all.length ? all.length : start + limit;
        final slice = all.sublist(start, end);
        developer.log(
          'Loaded ${slice.length} purchase rows as wallet history (page $page, total ${all.length})',
          name: 'WalletService',
        );
        return slice;
      }

      developer.log(
        'getTransactions: orders API not usable for table (ok=$ok rawListNull=${rawList == null} keys=${result.keys.toList()}). Same endpoint as Purchases: GET /orders.',
        name: 'WalletService',
      );
      return [];
    } catch (e) {
      developer.log('Error getting transactions from orders: $e',
          name: 'WalletService');
      return [];
    }
  }

  /// Accepts both `data: [...]` and `data: { orders: [...] }` shapes.
  static List<dynamic>? _extractOrdersListFromGetOrdersResult(
    Map<String, dynamic> result,
  ) {
    final data = result['data'];
    if (data is List) {
      return List<dynamic>.from(data);
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      for (final key in <String>['orders', 'data', 'list', 'items']) {
        final v = m[key];
        if (v is List) return List<dynamic>.from(v);
      }
    }
    return null;
  }

  /// One row per raw API object when grouping throws.
  static List<Map<String, dynamic>> _orderRowsFallbackWithoutGrouping(
    List<dynamic> raw,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final o in raw) {
      if (o is! Map) continue;
      try {
        out.add(Map<String, dynamic>.from(o));
      } catch (_) {}
    }
    out.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime(1970);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime(1970);
      return db.compareTo(da);
    });
    return out;
  }

  static WalletTransaction _walletTransactionFromOrderRow(
    Map<String, dynamic> o,
    String userId,
  ) {
    final ref = (o['transaction_id'] ?? o['order_id'] ?? o['delivery_id'] ?? '')
        .toString();
    final amount = _toAmount(o['total_price'] ?? o['price']);
    final isMulti = o['is_multi_item'] == true;
    final count = (o['item_count'] ?? 1) is num
        ? (o['item_count'] as num).toInt()
        : int.tryParse('${o['item_count'] ?? 1}') ?? 1;
    final product = o['product_name']?.toString() ?? 'Purchase';
    final desc = isMulti && count > 1
        ? '$product (+${count - 1} more)'
        : product;
    final id = ref.isNotEmpty
        ? ref
        : '${o['created_at']}_$product'.hashCode.abs().toString();
    return WalletTransaction(
      id: id,
      walletId: userId,
      type: 'debit',
      amount: amount,
      description: desc,
      reference: ref.isNotEmpty ? ref : (o['order_id']?.toString() ?? ''),
      status: _orderStatusToWalletStatus(o['status']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(o['created_at']?.toString() ?? '') ?? DateTime.now(),
      metadata: {
        'source': 'orders',
        'payment_method': o['payment_method'] ?? o['payment_type'],
      },
    );
  }

  static double _toAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _orderStatusToWalletStatus(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('fail') ||
        s.contains('cancel') ||
        s.contains('declin') ||
        s.contains('reject')) {
      return 'failed';
    }
    if (s.contains('pending') || s.contains('process')) {
      return 'pending';
    }
    return 'completed';
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
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
