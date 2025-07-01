// services/app_state_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AppStateService extends ChangeNotifier {
  // Singleton pattern
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  // App state variables
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnline = true;
  String _currentTheme = 'light';
  String _currentLanguage = 'en';
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _recentSearches = [];
  List<Map<String, dynamic>> _favorites = [];
  Map<String, dynamic> _appSettings = {};
  int _cartItemCount = 0;
  List<Map<String, dynamic>> _notifications = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOnline => _isOnline;
  String get currentTheme => _currentTheme;
  String get currentLanguage => _currentLanguage;
  Map<String, dynamic>? get userProfile => _userProfile;
  List<Map<String, dynamic>> get recentSearches => _recentSearches;
  List<Map<String, dynamic>> get favorites => _favorites;
  Map<String, dynamic> get appSettings => _appSettings;
  int get cartItemCount => _cartItemCount;
  List<Map<String, dynamic>> get notifications => _notifications;

  // Initialize app state
  Future<void> initialize() async {
    await _loadFromStorage();
    _setupConnectivityListener();
  }

  // Loading state management
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Error state management
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Online/Offline state
  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }

  // Theme management
  void setTheme(String theme) {
    _currentTheme = theme;
    _saveToStorage();
    notifyListeners();
  }

  // Language management
  void setLanguage(String language) {
    _currentLanguage = language;
    _saveToStorage();
    notifyListeners();
  }

  // User profile management
  void setUserProfile(Map<String, dynamic>? profile) {
    _userProfile = profile;
    _saveToStorage();
    notifyListeners();
  }

  void updateUserProfile(Map<String, dynamic> updates) {
    if (_userProfile != null) {
      _userProfile!.addAll(updates);
      _saveToStorage();
      notifyListeners();
    }
  }

  // Recent searches management
  void addRecentSearch(String query) {
    final search = {
      'query': query,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Remove if already exists
    _recentSearches.removeWhere((item) => item['query'] == query);

    // Add to beginning
    _recentSearches.insert(0, search);

    // Keep only last 10 searches
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }

    _saveToStorage();
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    _saveToStorage();
    notifyListeners();
  }

  // Favorites management
  void addToFavorites(Map<String, dynamic> item) {
    final itemId = item['id']?.toString();
    if (itemId != null) {
      // Remove if already exists
      _favorites.removeWhere((fav) => fav['id']?.toString() == itemId);

      // Add to favorites
      _favorites.add({
        ...item,
        'addedAt': DateTime.now().toIso8601String(),
      });

      _saveToStorage();
      notifyListeners();
    }
  }

  void removeFromFavorites(String itemId) {
    _favorites.removeWhere((fav) => fav['id']?.toString() == itemId);
    _saveToStorage();
    notifyListeners();
  }

  bool isFavorite(String itemId) {
    return _favorites.any((fav) => fav['id']?.toString() == itemId);
  }

  // App settings management
  void updateAppSettings(Map<String, dynamic> settings) {
    _appSettings.addAll(settings);
    _saveToStorage();
    notifyListeners();
  }

  void setAppSetting(String key, dynamic value) {
    _appSettings[key] = value;
    _saveToStorage();
    notifyListeners();
  }

  T? getAppSetting<T>(String key, {T? defaultValue}) {
    final value = _appSettings[key];
    if (value != null && value is T) {
      return value;
    }
    return defaultValue;
  }

  // Cart management
  void setCartItemCount(int count) {
    _cartItemCount = count;
    _saveToStorage();
    notifyListeners();
  }

  void incrementCartItemCount() {
    _cartItemCount++;
    _saveToStorage();
    notifyListeners();
  }

  void decrementCartItemCount() {
    if (_cartItemCount > 0) {
      _cartItemCount--;
      _saveToStorage();
      notifyListeners();
    }
  }

  // Notifications management
  void addNotification(Map<String, dynamic> notification) {
    _notifications.insert(0, {
      ...notification,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    });

    // Keep only last 50 notifications
    if (_notifications.length > 50) {
      _notifications = _notifications.take(50).toList();
    }

    _saveToStorage();
    notifyListeners();
  }

  void markNotificationAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['read'] = true;
      _saveToStorage();
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    for (var notification in _notifications) {
      notification['read'] = true;
    }
    _saveToStorage();
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    _saveToStorage();
    notifyListeners();
  }

  int get unreadNotificationCount {
    return _notifications.where((n) => n['read'] == false).length;
  }

  // Storage management
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('app_theme', _currentTheme);
      await prefs.setString('app_language', _currentLanguage);
      await prefs.setString('recent_searches', json.encode(_recentSearches));
      await prefs.setString('favorites', json.encode(_favorites));
      await prefs.setString('app_settings', json.encode(_appSettings));
      await prefs.setInt('cart_item_count', _cartItemCount);
      await prefs.setString('notifications', json.encode(_notifications));

      if (_userProfile != null) {
        await prefs.setString('user_profile', json.encode(_userProfile));
      }
    } catch (e) {
      debugPrint('Error saving app state: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _currentTheme = prefs.getString('app_theme') ?? 'light';
      _currentLanguage = prefs.getString('app_language') ?? 'en';
      _cartItemCount = prefs.getInt('cart_item_count') ?? 0;

      // Load recent searches
      final searchesJson = prefs.getString('recent_searches');
      if (searchesJson != null) {
        _recentSearches = List<Map<String, dynamic>>.from(
          json.decode(searchesJson),
        );
      }

      // Load favorites
      final favoritesJson = prefs.getString('favorites');
      if (favoritesJson != null) {
        _favorites = List<Map<String, dynamic>>.from(
          json.decode(favoritesJson),
        );
      }

      // Load app settings
      final settingsJson = prefs.getString('app_settings');
      if (settingsJson != null) {
        _appSettings = Map<String, dynamic>.from(
          json.decode(settingsJson),
        );
      }

      // Load notifications
      final notificationsJson = prefs.getString('notifications');
      if (notificationsJson != null) {
        _notifications = List<Map<String, dynamic>>.from(
          json.decode(notificationsJson),
        );
      }

      // Load user profile
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        _userProfile = Map<String, dynamic>.from(
          json.decode(profileJson),
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading app state: $e');
    }
  }

  // Connectivity listener setup
  void _setupConnectivityListener() {
    // This would be implemented with connectivity_plus package
    // For now, we'll assume online by default
    _isOnline = true;
  }

  // Clear all data
  Future<void> clearAllData() async {
    _recentSearches.clear();
    _favorites.clear();
    _notifications.clear();
    _cartItemCount = 0;
    _appSettings.clear();
    _userProfile = null;

    await _saveToStorage();
    notifyListeners();
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _currentTheme = 'light';
    _currentLanguage = 'en';
    _appSettings = {
      'notifications_enabled': true,
      'auto_refresh': true,
      'cache_enabled': true,
      'analytics_enabled': true,
    };

    await _saveToStorage();
    notifyListeners();
  }
}
