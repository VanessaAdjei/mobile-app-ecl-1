import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  Future<void> login() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    notifyListeners();
  }
}