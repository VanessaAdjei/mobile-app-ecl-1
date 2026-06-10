// services/realtime_cart_sync_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../providers/cart_provider.dart';
import 'auth_service.dart';
import '../utils/app_error_utils.dart';

/// Keeps the local cart reconciled with the server in the background (not only on add).
class RealtimeCartSyncService {
  static final RealtimeCartSyncService _instance =
      RealtimeCartSyncService._internal();
  factory RealtimeCartSyncService() => _instance;
  RealtimeCartSyncService._internal();

  Timer? _immediateSyncTimer;
  Timer? _periodicSyncTimer;
  Timer? _initialSyncTimer;
  bool _isRunning = false;
  CartProvider? _cartProvider;

  static const Duration _immediateSyncDelay = Duration(milliseconds: 800);
  static const Duration _periodicSyncInterval = Duration(minutes: 2);
  static const Duration _initialSyncDelay = Duration(seconds: 15);

  Future<void> initialize(CartProvider cartProvider) async {
    if (_isRunning) {
      _cartProvider = cartProvider;
      return;
    }

    _cartProvider = cartProvider;
    _isRunning = true;

    _scheduleInitialSync();
    _startPeriodicSync();

    debugPrint(
      '🛒 RealtimeCartSyncService: started (initial ${_initialSyncDelay.inSeconds}s, '
      'then every ${_periodicSyncInterval.inMinutes} min)',
    );
  }

  void _scheduleInitialSync() {
    _initialSyncTimer?.cancel();
    _initialSyncTimer = Timer(_initialSyncDelay, () {
      if (_isRunning) {
        unawaited(_performImmediateSync());
      }
    });
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (_isRunning) {
        unawaited(_performPeriodicSync());
      }
    });
  }

  /// Debounced sync after local cart mutations (add, qty change, remove).
  Future<void> triggerImmediateSync() async {
    if (!_isRunning) return;

    _immediateSyncTimer?.cancel();
    _immediateSyncTimer = Timer(_immediateSyncDelay, () {
      unawaited(_performImmediateSync());
    });
  }

  /// Immediate sync (app resume, manual refresh).
  static Future<void> checkNow() async {
    await _instance.forceImmediateSync();
  }

  Future<void> _performImmediateSync() async {
    try {
      if (_cartProvider == null) return;
      if (!await _canSyncWithServer()) return;
      await _cartProvider!.syncWithApi();
    } catch (e, st) {
      AppErrorUtils.log('RealtimeCartSyncService._performImmediateSync', e, st);
    }
  }

  Future<void> _performPeriodicSync() async {
    try {
      if (_cartProvider == null) return;
      if (!await _canSyncWithServer()) return;
      debugPrint('🛒 RealtimeCartSyncService: periodic cart check');
      await _cartProvider!.syncWithApi();
    } catch (e, st) {
      AppErrorUtils.log('RealtimeCartSyncService._performPeriodicSync', e, st);
    }
  }

  Future<bool> _canSyncWithServer() async {
    if (!await AuthService.isLoggedIn()) return false;
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;
    final hashedLink = await AuthService.getHashedLink();
    return hashedLink != null && hashedLink.isNotEmpty;
  }

  Future<void> forceImmediateSync() async {
    _immediateSyncTimer?.cancel();
    await _performImmediateSync();
  }

  void stop() {
    _isRunning = false;
    _immediateSyncTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _initialSyncTimer?.cancel();
    _cartProvider = null;
    debugPrint('🛒 RealtimeCartSyncService: stopped');
  }

  bool get isRunning => _isRunning;

  Duration get immediateSyncDelay => _immediateSyncDelay;
  Duration get periodicSyncInterval => _periodicSyncInterval;
}
