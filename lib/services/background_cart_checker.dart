// services/background_cart_checker.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../providers/cart_provider.dart';
import 'auth_service.dart';

class BackgroundCartChecker {
  static final BackgroundCartChecker _instance =
      BackgroundCartChecker._internal();
  factory BackgroundCartChecker() => _instance;
  BackgroundCartChecker._internal();

  Timer? _cartCheckTimer;
  Timer? _periodicSyncTimer;
  bool _isRunning = false;
  CartProvider? _cartProvider;

  // how often to check and sync
  static const Duration _checkInterval =
      Duration(minutes: 2); // check every 2 minutes
  static const Duration _syncInterval =
      Duration(minutes: 5); // sync every 5 minutes
  static const Duration _initialDelay =
      Duration(seconds: 30); // start after 30 seconds

  // set up the background cart checker
  Future<void> initialize(CartProvider cartProvider) async {
    if (_isRunning) return;

    _cartProvider = cartProvider;
    _isRunning = true;

    developer.log('🛒 BackgroundCartChecker: Initializing...',
        name: 'CartChecker');

    // start checking cart periodically
    _startCartChecking();

    // start syncing with server periodically
    _startPeriodicSync();

    developer.log('🛒 BackgroundCartChecker: Initialized successfully',
        name: 'CartChecker');
  }

  // start checking cart periodically
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

  // start syncing with server periodically
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();

    // wait a bit before first sync
    Timer(_initialDelay, () {
      _performPeriodicSync();

      // then sync every 5 minutes
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

  // check for cart changes and handle them
  Future<void> _checkCartChanges() async {
    try {
      if (_cartProvider == null) return;

      // check if theyre logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return;
      }

      // check for any pending cart operations
      final cartItems = _cartProvider!.cartItems;

      await _cartProvider!.syncWithApi();
    } catch (e) {}
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
    } catch (e) {}
  }

  // force a cart check right away
  Future<void> forceCartCheck() async {
    await _checkCartChanges();
  }

  // force a server sync right away
  Future<void> forceServerSync() async {
    await _performPeriodicSync();
  }

  // stop the background cart checker
  void stop() {
    _isRunning = false;
    _cartCheckTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _cartProvider = null;

    developer.log('🛒 BackgroundCartChecker: Stopped', name: 'CartChecker');
  }

  // check if the background cart checker is running
  bool get isRunning => _isRunning;

  /// Get the current check interval
  Duration get checkInterval => _checkInterval;

  // get the current sync interval
  Duration get syncInterval => _syncInterval;
}
