// providers/wallet_provider.dart
import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../pages/auth_service.dart';

class WalletProvider extends ChangeNotifier {
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  double get balance => _wallet?.balance ?? 0.0;
  String get formattedBalance => WalletService.formatBalance(balance);
  bool get hasWallet => _wallet != null;

  // Initialize wallet provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await refreshWallet();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Refresh wallet data
  Future<void> refreshWallet() async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    try {
      final wallet = await WalletService.getWallet();
      if (wallet != null) {
        _wallet = wallet;
        await _loadTransactions();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load transactions
  Future<void> _loadTransactions() async {
    try {
      final transactions = await WalletService.getTransactions();
      _transactions = transactions;
      notifyListeners();
    } catch (e) {
      // Don't set error for transactions, just log it
      debugPrint('Error loading transactions: $e');
    }
  }

  // Load more transactions (pagination)
  Future<void> loadMoreTransactions() async {
    if (_isLoading) return;

    try {
      final currentPage = (_transactions.length / 20).ceil() + 1;
      final moreTransactions =
          await WalletService.getTransactions(page: currentPage);

      if (moreTransactions.isNotEmpty) {
        _transactions.addAll(moreTransactions);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading more transactions: $e');
    }
  }

  Future<Map<String, dynamic>> processOrderCashback({
    required double orderAmount,
    required String orderId,
    VoidCallback? onCashbackSuccess,
  }) async {
    try {
      debugPrint(
          '🔄 WalletProvider: Starting MOCK cashback process for order $orderId (₵$orderAmount)');

      // 🔒 EXTRA PRECAUTION: Authentication check as backup security
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint(
            '🚫 WalletProvider: EXTRA CHECK - Guest user detected, cashback denied');
        return {
          'success': false,
          'message':
              'Cashback is only available for registered users. Please log in or create an account.',
          'cashback_amount': 0.0,
          'qualifies': false,
          'is_mock': true,
          'auth_required': true,
        };
      }

      // 🔒 EXTRA PRECAUTION: User ID validation
      final userId = await AuthService.getCurrentUserID();
      if (userId == null) {
        debugPrint(
            '🚫 WalletProvider: EXTRA CHECK - Could not get user ID, cashback denied');
        return {
          'success': false,
          'message': 'User authentication failed. Please log in again.',
          'cashback_amount': 0.0,
          'qualifies': false,
          'is_mock': true,
          'auth_required': true,
        };
      }

      // Check if wallet is initialized
      if (!_isInitialized) {
        debugPrint(
            '🔄 WalletProvider: Wallet not initialized, initializing now...');
        await initialize();
      }

      // Ensure wallet exists for authenticated user
      if (_wallet == null) {
        debugPrint(
            '🔄 WalletProvider: Creating wallet for authenticated user: $userId');
        _wallet = Wallet(
          id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          balance: 0.0,
          currency: 'GHS',
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      final result = await WalletService.autoProcessCashback(
        orderAmount: orderAmount,
        orderId: orderId,
      );

      debugPrint('🔄 WalletProvider: MOCK Cashback result: $result');

      if (result['success'] && result['is_mock'] == true) {
        debugPrint(
            '🔄 WalletProvider: MOCK Cashback successful, simulating wallet update...');

        // MOCK: Simulate adding cashback to wallet balance
        final cashbackAmount = result['cashback_amount'] as double;
        _wallet = _wallet!.copyWith(
          balance: _wallet!.balance + cashbackAmount,
        );

        // Add mock transaction
        final mockTransaction = WalletTransaction(
          id: 'mock_cashback_${DateTime.now().millisecondsSinceEpoch}',
          walletId: _wallet!.id,
          type: 'cashback',
          amount: cashbackAmount,
          description: result['message'],
          reference: 'MOCK_CASHBACK_$orderId',
          status: 'completed',
          createdAt: DateTime.now(),
          metadata: {
            'order_id': orderId,
            'order_amount': orderAmount,
            'is_mock': true,
          },
        );

        _transactions.insert(0, mockTransaction);
        debugPrint(
            '🔄 WalletProvider: MOCK Wallet updated successfully. New balance: ₵${_wallet!.balance}');

        // Notify listeners to update UI
        notifyListeners();

        // Invoke callback if provided (e.g., navigate to wallet)
        if (onCashbackSuccess != null) {
          onCashbackSuccess();
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ WalletProvider: Error in MOCK cashback process: $e');
      return {
        'success': false,
        'message': 'MOCK: Failed to process cashback: ${e.toString()}',
        'cashback_amount': 0.0,
        'qualifies': false,
        'is_mock': true,
      };
    }
  }

  // Top up wallet
  Future<Map<String, dynamic>> topUpWallet({
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    if (_isLoading) {
      return {'success': false, 'message': 'Operation in progress'};
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await WalletService.topUpWallet(
        amount: amount,
        paymentMethod: paymentMethod,
        reference: reference,
      );

      if (result['success']) {
        // Refresh wallet data
        await refreshWallet();
      }

      return result;
    } catch (e) {
      final errorMessage = e.toString();
      _setError(errorMessage);
      return {'success': false, 'message': errorMessage};
    } finally {
      _setLoading(false);
    }
  }

  // Process refund to wallet
  Future<Map<String, dynamic>> processRefund({
    required double amount,
    required String orderId,
    required String reason,
    String? description,
  }) async {
    if (_isLoading) {
      return {'success': false, 'message': 'Operation in progress'};
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await WalletService.processRefund(
        amount: amount,
        orderId: orderId,
        reason: reason,
        description: description,
      );

      if (result['success']) {
        // Refresh wallet data
        await refreshWallet();
      }

      return result;
    } catch (e) {
      final errorMessage = e.toString();
      _setError(errorMessage);
      return {'success': false, 'message': errorMessage};
    } finally {
      _setLoading(false);
    }
  }

  // Process cashback to wallet
  Future<Map<String, dynamic>> processCashback({
    required double amount,
    required String orderId,
    required String reason,
    String? description,
  }) async {
    if (_isLoading) {
      return {'success': false, 'message': 'Operation in progress'};
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await WalletService.processCashback(
        amount: amount,
        orderId: orderId,
        reason: reason,
        description: description,
      );

      if (result['success']) {
        // Refresh wallet data
        await refreshWallet();
      }

      return result;
    } catch (e) {
      final errorMessage = e.toString();
      _setError(errorMessage);
      return {'success': false, 'message': errorMessage};
    } finally {
      _setLoading(false);
    }
  }

  // Use wallet balance for payment
  Future<Map<String, dynamic>> useWalletBalance({
    required double amount,
    required String orderId,
    String? description,
  }) async {
    if (_isLoading) {
      return {'success': false, 'message': 'Operation in progress'};
    }

    if (balance < amount) {
      return {'success': false, 'message': 'Insufficient wallet balance'};
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await WalletService.useWalletBalance(
        amount: amount,
        orderId: orderId,
        description: description,
      );

      if (result['success']) {
        // Refresh wallet data
        await refreshWallet();
      }

      return result;
    } catch (e) {
      final errorMessage = e.toString();
      _setError(errorMessage);
      return {'success': false, 'message': errorMessage};
    } finally {
      _setLoading(false);
    }
  }

  // Check if user has sufficient balance
  Future<bool> hasSufficientBalance(double amount) async {
    try {
      return await WalletService.hasSufficientBalance(amount);
    } catch (e) {
      return false;
    }
  }

  // Create wallet if it doesn't exist
  Future<void> createWallet() async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    try {
      final wallet = await WalletService.createWallet();
      _wallet = wallet;
      await _loadTransactions();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Clear wallet data (on logout)
  void clearWallet() {
    _wallet = null;
    _transactions.clear();
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Get transaction by ID
  WalletTransaction? getTransactionById(String id) {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get recent transactions (last 5)
  List<WalletTransaction> get recentTransactions {
    return _transactions.take(5).toList();
  }

  // Get transactions by type
  List<WalletTransaction> getTransactionsByType(String type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  // Get total credits
  double get totalCredits {
    return _transactions
        .where((t) => t.isCredit && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get total debits
  double get totalDebits {
    return _transactions
        .where((t) => t.isDebit && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get total refunds
  double get totalRefunds {
    return _transactions
        .where((t) => t.isRefund && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get total cashback
  double get totalCashback {
    return _transactions
        .where((t) => t.isCashback && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get total returns
  double get totalReturns {
    return _transactions
        .where((t) => t.isReturn && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get total bonuses
  double get totalBonuses {
    return _transactions
        .where((t) => t.isBonus && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get pending transactions
  List<WalletTransaction> get pendingTransactions {
    return _transactions.where((t) => t.isPending).toList();
  }

  // Get failed transactions
  List<WalletTransaction> get failedTransactions {
    return _transactions.where((t) => t.isFailed).toList();
  }

  // Check if wallet is active
  bool get isWalletActive {
    return _wallet?.status == 'active';
  }

  // Get wallet creation date
  DateTime? get walletCreatedAt {
    return _wallet?.createdAt;
  }

  // Get wallet last update date
  DateTime? get walletLastUpdated {
    return _wallet?.updatedAt;
  }

  // Format currency
  String formatCurrency(double amount) {
    return WalletService.formatBalance(amount);
  }

  // Get transaction type display text
  String getTransactionTypeText(String type) {
    return WalletService.getTransactionTypeText(type);
  }

  // Get transaction status color
  int getTransactionStatusColor(String status) {
    return WalletService.getTransactionStatusColor(status);
  }
}
