import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileSettingsProvider extends ChangeNotifier {
  ProfileSettingsProvider({ProfileService? service})
      : _service = service ?? ProfileService();

  final ProfileService _service;

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isChangingPassword => _isChangingPassword;
  String? get error => _error;

  Future<void> loadProfile({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _service.getProfile(cacheLocally: true);
      _profile = profile;
    } catch (e) {
      _error = e.toString();
      debugPrint('ProfileSettingsProvider.loadProfile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fname,
    required String email,
    String? number,
    String? addr1,
    double? lat,
    double? lng,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _service.updateProfile(
        fname: fname,
        email: email,
        number: number,
        addr1: addr1,
        lat: lat,
        lng: lng,
      );
      _profile = profile;
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('ProfileSettingsProvider.updateProfile: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isChangingPassword = true;
    _error = null;
    notifyListeners();

    try {
      await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return null;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _error = message;
      debugPrint('ProfileSettingsProvider.changePassword: $e');
      return message;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }

  void clear() {
    _profile = null;
    _error = null;
    _isLoading = false;
    _isSaving = false;
    _isChangingPassword = false;
    notifyListeners();
  }
}
