// services/background_cart_checker.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../pages/cartprovider.dart';
import '../pages/auth_service.dart';

class BackgroundCartChecker {
  static final BackgroundCartChecker _instance =
      BackgroundCartChecker._internal();
  factory BackgroundCartChecker() => _instance;
  BackgroundCartChecker._internal();

  Timer? _cartCheckTimer;
  Timer? _periodicSyncTimer;
  bool _isRunning = false;
  CartProvider? _cartProvider;

  // Configuration
  static const Duration _checkInterval =
      Duration(minutes: 2); // Check every 2 minutes
  static const Duration _syncInterval =
      Duration(minutes: 5); // Sync every 5 minutes
  static const Duration _initialDelay =
      Duration(seconds: 30); // Start after 30 seconds

  /// Initialize the background cart checker
  Future<void> initialize(CartProvider cartProvider) async {
    if (_isRunning) return;

    _cartProvider = cartProvider;
    _isRunning = true;

    developer.log('🛒 BackgroundCartChecker: Initializing...',
        name: 'CartChecker');

    // Start periodic cart checking
    _startCartChecking();

    // Start periodic server sync
    _startPeriodicSync();

    developer.log('🛒 BackgroundCartChecker: Initialized successfully',
        name: 'CartChecker');
  }

  /// Start periodic cart checking
  void _startCartChecking() {
    _cartCheckTimer?.cancel();

    _cartCheckTimer = Timer.periodic(_checkInterval, (timer) {
      if (_isRunning) {
        _checkCartChanges();
      }
    });

    developer.log(
        '🛒 BackgroundCartChecker: Cart checking started (every ${_checkInterval.inMinutes} minutes)',
        name: 'CartChecker');
  }

  /// Start periodic server sync
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();

    // Initial delay before first sync
    Timer(_initialDelay, () {
      _performPeriodicSync();

      // Then sync every 5 minutes
      _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) {
        if (_isRunning) {
          _performPeriodicSync();
        }
      });
    });

    developer.log(
        '🛒 BackgroundCartChecker: Periodic sync scheduled (every ${_syncInterval.inMinutes} minutes)',
        name: 'CartChecker');
  }

  /// Check for cart changes and handle them
  Future<void> _checkCartChanges() async {
    try {
      if (_cartProvider == null) return;



      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {

        return;
      }

      // Check for any pending cart operations
      final cartItems = _cartProvider!.cartItems;

      await _cartProvider!.syncWithApi();
    } catch (e) {

    }
  }

  /// Perform periodic server sync
  Future<void> _performPeriodicSync() async {
    try {
      if (_cartProvider == null) return;

      debugPrint('🛒 BackgroundCartChecker: Performing periodic sync...');

      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint(
            '🛒 BackgroundCartChecker: User not logged in, skipping periodic sync');
        return;
      }

      // Sync with server
      await _cartProvider!.syncWithApi();


    } catch (e) {
     
    }
  }

  /// Force a cart check immediately
  Future<void> forceCartCheck() async {
    
    await _checkCartChanges();
  }

  /// Force a server sync immediately
  Future<void> forceServerSync() async {

    await _performPeriodicSync();
  }

  /// Stop the background cart checker
  void stop() {
    _isRunning = false;
    _cartCheckTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _cartProvider = null;

    developer.log('🛒 BackgroundCartChecker: Stopped', name: 'CartChecker');
  }

  /// Check if the background cart checker is running
  bool get isRunning => _isRunning;

  /// Get the current check interval
  Duration get checkInterval => _checkInterval;

  /// Get the current sync interval
  Duration get syncInterval => _syncInterval;
}
