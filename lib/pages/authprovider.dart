// pages/authprovider.dart
import 'package:flutter/material.dart';
import 'package:eclapp/pages/auth_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      _isLoggedIn = await AuthService.isLoggedIn();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> login() async {
    try {
      // Force update AuthService state first
      await AuthService.forceUpdateAuthState();
      // Then check the login state
      _isLoggedIn = await AuthService.isLoggedIn();
      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await AuthService.logout();
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> refreshAuthState() async {
    await login();
  }
}
