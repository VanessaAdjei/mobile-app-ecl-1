// providers/wallet_provider.dart
import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // getters to access the wallet data
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  double get balance => totalCashback + totalRefunds;
  String get formattedBalance => WalletService.formatBalance(balance);
  bool get hasWallet => _wallet != null;

  // set up the wallet provider
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

  // reload wallet data from the api
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

  // load the transaction history
  Future<void> _loadTransactions() async {
    try {
      final transactions = await WalletService.getTransactions();
      _transactions = transactions;
      notifyListeners();
    } catch (e) {
      // dont show error for transactions, just print it
      debugPrint('Error loading transactions: $e');
    }
  }

  // load more transactions (for pagination)
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
          '🔄 WalletProvider: Cashback processing disabled for order $orderId (₵$orderAmount)');

      // return a message saying its disabled
      return {
        'success': false,
        'message': 'Cashback feature is currently disabled',
        'cashback_amount': 0.0,
        'qualifies': false,
        'is_mock': false,
      };
    } catch (e) {
      debugPrint('❌ WalletProvider: Error in cashback process: $e');
      return {
        'success': false,
        'message': 'Failed to process cashback: ${e.toString()}',
        'cashback_amount': 0.0,
        'qualifies': false,
        'is_mock': false,
      };
    }
  }

  // add money to the wallet
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
        // reload wallet data
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

  // add a refund to the wallet
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
        // reload wallet data
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

  // add cashback to the wallet
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
        // reload wallet data
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

  // use wallet money to pay for something
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
        // reload wallet data
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

  // check if they have enough money in the wallet
  Future<bool> hasSufficientBalance(double amount) async {
    try {
      return await WalletService.hasSufficientBalance(amount);
    } catch (e) {
      return false;
    }
  }

  // make a wallet if they dont have one yet
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

  // clear wallet data when they log out
  void clearWallet() {
    _wallet = null;
    _transactions.clear();
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }

  // helper methods (private stuff)
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

  // find a transaction by its id
  WalletTransaction? getTransactionById(String id) {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // get the last 5 transactions
  List<WalletTransaction> get recentTransactions {
    return _transactions.take(5).toList();
  }

  // get transactions of a specific type
  List<WalletTransaction> getTransactionsByType(String type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  // add up all the money they spent
  double get totalDebits {
    return _transactions
        .where((t) => t.isDebit && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // add up all the refunds they got
  double get totalRefunds {
    return _transactions
        .where((t) => t.isRefund && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // add up all the cashback they earned
  double get totalCashback {
    return _transactions
        .where((t) => t.isCashback && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // add up all the returns
  double get totalReturns {
    return _transactions
        .where((t) => t.isReturn && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // add up all the bonuses
  double get totalBonuses {
    return _transactions
        .where((t) => t.isBonus && t.isCompleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // get transactions that are still pending
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
