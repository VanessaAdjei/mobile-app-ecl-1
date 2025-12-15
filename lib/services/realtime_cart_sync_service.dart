// services/realtime_cart_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/cartprovider.dart';
import '../pages/auth_service.dart';

class RealtimeCartSyncService {
  static final RealtimeCartSyncService _instance =
      RealtimeCartSyncService._internal();
  factory RealtimeCartSyncService() => _instance;
  RealtimeCartSyncService._internal();

  Timer? _immediateSyncTimer;
  Timer? _periodicSyncTimer;
  bool _isRunning = false;
  CartProvider? _cartProvider;

  // how long to wait before syncing
  static const Duration _immediateSyncDelay =
      Duration(milliseconds: 500); // wait 500ms
  static const Duration _periodicSyncInterval =
      Duration(minutes: 1); // sync every 1 minute
  static const Duration _syncTimeout = Duration(seconds: 10);

  // set up the real-time cart sync service
  Future<void> initialize(CartProvider cartProvider) async {
    if (_isRunning) return;

    _cartProvider = cartProvider;
    _isRunning = true;

    // Start immediate sync mechanism
    _startImmediateSync();

    // Start periodic sync as backup
    _startPeriodicSync();
  }

  // start immediate sync
  void _startImmediateSync() {
    _immediateSyncTimer?.cancel();

    // sync right away when service starts
    _performImmediateSync();
  }

  // start periodic sync as backup
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();

    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (timer) {
      if (_isRunning) {
        _performPeriodicSync();
      }
    });
  }

  /// Trigger immediate cart sync (called when cart changes)
  Future<void> triggerImmediateSync() async {
    if (!_isRunning) return;

    // Cancel any pending immediate sync
    _immediateSyncTimer?.cancel();

    // Schedule immediate sync with small delay to batch rapid changes
    _immediateSyncTimer = Timer(_immediateSyncDelay, () {
      _performImmediateSync();
    });
  }

  // do immediate cart sync
  Future<void> _performImmediateSync() async {
    try {
      if (_cartProvider == null) return;

      // check if theyre logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return;
      }

      // sync with server right away
      await _cartProvider!.syncWithApi();
    } catch (e) {}
  }

  /// Perform periodic sync as backup
  Future<void> _performPeriodicSync() async {
    try {
      if (_cartProvider == null) return;

      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return;
      }

      // Sync with server
      await _cartProvider!.syncWithApi();
    } catch (e) {}
  }

  // force an immediate sync (for manual refresh)
  Future<void> forceImmediateSync() async {
    await _performImmediateSync();
  }

  /// Stop the real-time cart sync service
  void stop() {
    _isRunning = false;
    _immediateSyncTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _cartProvider = null;
  }

  // check if the service is running
  bool get isRunning => _isRunning;

  // get the current sync intervals
  Duration get immediateSyncDelay => _immediateSyncDelay;
  Duration get periodicSyncInterval => _periodicSyncInterval;
}
