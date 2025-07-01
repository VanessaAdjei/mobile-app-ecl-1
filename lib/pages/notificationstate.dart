import 'package:flutter/material.dart';

class NotificationState extends ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }

  void markAsRead() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  void resetUnread() {
    _unreadCount = 0;
    notifyListeners();
  }
}